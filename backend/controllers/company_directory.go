package controllers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/gustavogomes000/singproof-go/config"
	"github.com/gustavogomes000/singproof-go/models"
	"gorm.io/gorm/clause"
)

type bluepointDepartment struct {
	ID                int64  `json:"id"`
	Name              string `json:"nome"`
	Description       string `json:"descricao"`
	Status            string `json:"status"`
	TotalCollaborator int    `json:"totalColaboradores"`
}

type bluepointCargo struct {
	ID          int64  `json:"id"`
	Name        string `json:"nome"`
	Description string `json:"descricao"`
	CBO         string `json:"cbo"`
}

type bluepointCollaborator struct {
	ID     int64  `json:"id"`
	Name   string `json:"nome"`
	Email  string `json:"email"`
	Status string `json:"status"`
	Photo  string `json:"foto"`
	Cargo  *struct {
		ID   int64  `json:"id"`
		Name string `json:"nome"`
	} `json:"cargo"`
}

func bluepointBaseURL() string {
	base := strings.TrimSpace(os.Getenv("BLUEPOINT_API_BASE_URL"))
	if base == "" {
		base = "https://bluepoint-api.bluetechfilms.com.br"
	}
	return strings.TrimSuffix(base, "/")
}

func bluepointToken() string {
	token := strings.TrimSpace(os.Getenv("BLUEPOINT_API_TOKEN"))
	return token
}

func callBluepoint(path string) ([]byte, error) {
	token := bluepointToken()
	if token == "" {
		return nil, fiber.NewError(fiber.StatusPreconditionFailed, "BLUEPOINT_API_TOKEN nao configurado")
	}

	endpoint := fmt.Sprintf("%s%s", bluepointBaseURL(), path)
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+token)

	client := &http.Client{Timeout: 12 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fiber.NewError(resp.StatusCode, fmt.Sprintf("BluePoint retornou status %d", resp.StatusCode))
	}
	return body, nil
}

func decodeBluepointArray(raw []byte, out any) error {
	var payload struct {
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(raw, &payload); err != nil {
		return err
	}
	if len(payload.Data) == 0 {
		return json.Unmarshal(raw, out)
	}
	if err := json.Unmarshal(payload.Data, out); err == nil {
		return nil
	}
	var nested struct {
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(payload.Data, &nested); err != nil {
		return err
	}
	return json.Unmarshal(nested.Data, out)
}

func ensureLocalDepartment(companyID uuid.UUID, actorID uuid.UUID, depName string) (string, error) {
	depName = strings.TrimSpace(depName)
	if depName == "" {
		return "", nil
	}

	var dep models.Department
	err := config.DB.Where("company_id = ? AND lower(name) = ?", companyID, strings.ToLower(depName)).First(&dep).Error
	if err == nil {
		return dep.ID.String(), nil
	}

	newDep := models.Department{
		CompanyID:   companyID,
		Name:        depName,
		Description: "Importado da API BluePoint",
		Color:       "#14b8a6",
		CreatedBy:   actorID,
	}
	if err := config.DB.Create(&newDep).Error; err != nil {
		return "", err
	}
	return newDep.ID.String(), nil
}

func GetCompanyDirectoryOptions(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Acesso negado"})
	}
	userID := currentUserID(c)
	ensureLocal := strings.EqualFold(strings.TrimSpace(c.Query("ensure_local")), "true") || c.Query("ensure_local") == "1"

	departmentsBody, err := callBluepoint("/api/v1/listar-departamentos")
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": err.Error()})
	}
	cargosBody, err := callBluepoint("/api/v1/listar-cargos")
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": err.Error()})
	}

	var externalDepartments []bluepointDepartment
	if err := decodeBluepointArray(departmentsBody, &externalDepartments); err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "Falha ao parsear departamentos externos"})
	}
	var externalCargos []bluepointCargo
	if err := decodeBluepointArray(cargosBody, &externalCargos); err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "Falha ao parsear cargos externos"})
	}

	departments := make([]fiber.Map, 0, len(externalDepartments))
	for _, dep := range externalDepartments {
		item := fiber.Map{
			"id":                  dep.ID,
			"name":                dep.Name,
			"description":         dep.Description,
			"status":              dep.Status,
			"total_collaborators": dep.TotalCollaborator,
		}
		if ensureLocal {
			localID, localErr := ensureLocalDepartment(companyID, userID, dep.Name)
			if localErr == nil {
				item["local_department_id"] = localID
			}
		}
		departments = append(departments, item)
	}

	cargos := make([]fiber.Map, 0, len(externalCargos))
	for _, cargo := range externalCargos {
		cargos = append(cargos, fiber.Map{
			"id":          cargo.ID,
			"name":        cargo.Name,
			"description": cargo.Description,
			"cbo":         cargo.CBO,
		})
	}

	return c.JSON(fiber.Map{
		"departments": departments,
		"cargos":      cargos,
	})
}

func GetCompanyCollaboratorsByDepartment(c *fiber.Ctx) error {
	departmentID := strings.TrimSpace(c.Params("id"))
	if departmentID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID do departamento externo e obrigatorio"})
	}
	if _, err := strconv.ParseInt(departmentID, 10, 64); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ID do departamento externo invalido"})
	}

	path := fmt.Sprintf("/api/v1/listar-colaboradores-departamento/%s", url.PathEscape(departmentID))
	payload, err := fetchBluepointCollaboratorsByDepartmentPath(path)
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": err.Error()})
	}

	out := make([]fiber.Map, 0, len(payload.Data))
	for _, col := range payload.Data {
		item := fiber.Map{
			"id":     col.ID,
			"name":   col.Name,
			"email":  col.Email,
			"status": col.Status,
			"photo":  col.Photo,
		}
		if col.Cargo != nil {
			item["cargo_id"] = col.Cargo.ID
			item["cargo_name"] = col.Cargo.Name
		}
		out = append(out, item)
	}

	return c.JSON(fiber.Map{
		"department": fiber.Map{
			"id":   payload.Department.ID,
			"name": payload.Department.Name,
		},
		"collaborators": out,
	})
}

type bluepointDepartmentCollaboratorsPayload struct {
	Department struct {
		ID   int64  `json:"id"`
		Name string `json:"nome"`
	} `json:"departamento"`
	Data []bluepointCollaborator `json:"data"`
}

func fetchBluepointCollaboratorsByDepartmentPath(path string) (*bluepointDepartmentCollaboratorsPayload, error) {
	body, err := callBluepoint(path)
	if err != nil {
		return nil, err
	}
	var payload struct {
		Data bluepointDepartmentCollaboratorsPayload `json:"data"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("falha ao parsear colaboradores externos")
	}
	return &payload.Data, nil
}

func SyncCompanyCollaborators(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Acesso negado"})
	}

	departmentsBody, err := callBluepoint("/api/v1/listar-departamentos")
	if err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": err.Error()})
	}
	var externalDepartments []bluepointDepartment
	if err := decodeBluepointArray(departmentsBody, &externalDepartments); err != nil {
		return c.Status(fiber.StatusBadGateway).JSON(fiber.Map{"error": "Falha ao parsear departamentos externos"})
	}

	now := time.Now()
	staged := make([]models.CompanyExternalCollaborator, 0, 256)
	for _, dep := range externalDepartments {
		path := fmt.Sprintf("/api/v1/listar-colaboradores-departamento/%d", dep.ID)
		payload, fetchErr := fetchBluepointCollaboratorsByDepartmentPath(path)
		if fetchErr != nil {
			continue
		}
		for _, col := range payload.Data {
			rawMap := fiber.Map{
				"id":     col.ID,
				"name":   col.Name,
				"email":  col.Email,
				"status": col.Status,
				"photo":  col.Photo,
			}
			var cargoID *int64
			cargoName := ""
			if col.Cargo != nil {
				cargoID = &col.Cargo.ID
				cargoName = col.Cargo.Name
				rawMap["cargo"] = fiber.Map{
					"id":   col.Cargo.ID,
					"name": col.Cargo.Name,
				}
			}
			rawBytes, _ := json.Marshal(rawMap)
			depIDCopy := dep.ID
			staged = append(staged, models.CompanyExternalCollaborator{
				CompanyID:              companyID,
				ExternalCollaboratorID: col.ID,
				ExternalDepartmentID:   &depIDCopy,
				ExternalDepartmentName: dep.Name,
				FullName:               strings.TrimSpace(col.Name),
				Email:                  strings.TrimSpace(col.Email),
				Status:                 strings.TrimSpace(col.Status),
				PhotoURL:               strings.TrimSpace(col.Photo),
				CargoID:                cargoID,
				CargoName:              strings.TrimSpace(cargoName),
				RawPayload:             string(rawBytes),
				SyncedAt:               now,
			})
		}
	}

	if len(staged) > 0 {
		if err := config.DB.Clauses(clause.OnConflict{
			Columns: []clause.Column{
				{Name: "company_id"},
				{Name: "external_collaborator_id"},
			},
			DoUpdates: clause.Assignments(map[string]interface{}{
				"external_department_id":   gormExpr("EXCLUDED.external_department_id"),
				"external_department_name": gormExpr("EXCLUDED.external_department_name"),
				"full_name":                gormExpr("EXCLUDED.full_name"),
				"email":                    gormExpr("EXCLUDED.email"),
				"status":                   gormExpr("EXCLUDED.status"),
				"photo_url":                gormExpr("EXCLUDED.photo_url"),
				"cargo_id":                 gormExpr("EXCLUDED.cargo_id"),
				"cargo_name":               gormExpr("EXCLUDED.cargo_name"),
				"raw_payload":              gormExpr("EXCLUDED.raw_payload"),
				"synced_at":                gormExpr("EXCLUDED.synced_at"),
				"updated_at":               gormExpr("NOW()"),
			}),
		}).Create(&staged).Error; err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Falha ao salvar cache local de colaboradores"})
		}
	}

	return c.JSON(fiber.Map{
		"message":              "Sincronizacao concluida",
		"departments_scanned":  len(externalDepartments),
		"collaborators_synced": len(staged),
		"synced_at":            now,
	})
}

func ListSyncedCompanyCollaborators(c *fiber.Ctx) error {
	companyID, err := currentCompanyID(c)
	if err != nil {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "Acesso negado"})
	}
	search := strings.ToLower(strings.TrimSpace(c.Query("search")))
	status := strings.ToLower(strings.TrimSpace(c.Query("status")))
	departmentID := strings.TrimSpace(c.Query("department_id"))
	limit := c.QueryInt("limit", 50)
	if limit < 1 {
		limit = 50
	}
	if limit > 500 {
		limit = 500
	}

	q := config.DB.Model(&models.CompanyExternalCollaborator{}).Where("company_id = ?", companyID)
	if search != "" {
		q = q.Where("LOWER(full_name) LIKE ? OR LOWER(email) LIKE ?", "%"+search+"%", "%"+search+"%")
	}
	if status != "" && status != "all" {
		q = q.Where("LOWER(status) = ?", status)
	}
	if departmentID != "" {
		if depIDInt, parseErr := strconv.ParseInt(departmentID, 10, 64); parseErr == nil {
			q = q.Where("external_department_id = ?", depIDInt)
		}
	}

	var rows []models.CompanyExternalCollaborator
	if err := q.Order("full_name asc").Limit(limit).Find(&rows).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Falha ao consultar colaboradores sincronizados"})
	}
	resp := make([]fiber.Map, 0, len(rows))
	for _, row := range rows {
		resp = append(resp, fiber.Map{
			"id":                       row.ID,
			"external_collaborator_id": row.ExternalCollaboratorID,
			"name":                     row.FullName,
			"email":                    row.Email,
			"status":                   row.Status,
			"photo_url":                row.PhotoURL,
			"external_department_id":   row.ExternalDepartmentID,
			"external_department_name": row.ExternalDepartmentName,
			"external_cargo_id":        row.CargoID,
			"external_cargo_name":      row.CargoName,
			"synced_at":                row.SyncedAt,
		})
	}
	return c.JSON(fiber.Map{"collaborators": resp, "count": len(resp)})
}

func gormExpr(expression string) clause.Expr {
	return clause.Expr{SQL: expression}
}
