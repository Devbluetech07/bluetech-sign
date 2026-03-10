package routes

import (
	"github.com/gofiber/fiber/v2"
	"github.com/gustavogomes000/singproof-go/controllers"
	"github.com/gustavogomes000/singproof-go/middlewares"
)

func SetupRoutes(router fiber.Router) {
	authGroup := router.Group("/auth")
	authGroup.Post("/login", controllers.Login)
	authGroup.Post("/register", controllers.Register) // Utilitário de Bootstrap

	documentsGroup := router.Group("/documents", middlewares.ProtectedMiddleware())
	documentsGroup.Get("/", controllers.GetDocuments)
	documentsGroup.Get("/:id", controllers.GetDocumentDetail)
	documentsGroup.Get("/:id/audit", controllers.GetDocumentAudit)
	documentsGroup.Get("/:id/download", controllers.DownloadDocumentByID)
	documentsGroup.Post("/upload", controllers.UploadDocument)
	documentsGroup.Post("/from-template", controllers.CreateDocumentFromTemplate)
	documentsGroup.Post("/:id/signers", controllers.AddSigner)
	documentsGroup.Post("/:id/fields", controllers.AddDocumentFields)
	documentsGroup.Post("/:id/validation-steps", controllers.CreateValidationSteps)
	documentsGroup.Put("/:id/config", controllers.UpdateDocumentConfig)
	documentsGroup.Post("/:id/send", controllers.SendDocument)
	documentsGroup.Post("/:id/cancel", controllers.CancelDocument)
	documentsGroup.Post("/:id/resend", controllers.ResendDocument)

	contactsGroup := router.Group("/contacts", middlewares.ProtectedMiddleware())
	contactsGroup.Get("/", controllers.GetContacts)
	contactsGroup.Post("/", controllers.CreateContact)
	contactsGroup.Put("/:id", controllers.UpdateContact)
	contactsGroup.Delete("/:id", controllers.DeleteContact)

	templatesGroup := router.Group("/templates", middlewares.ProtectedMiddleware())
	templatesGroup.Get("/", controllers.GetTemplates)
	templatesGroup.Post("/", controllers.CreateTemplate)
	templatesGroup.Put("/:id", controllers.UpdateTemplate)
	templatesGroup.Delete("/:id", controllers.DeleteTemplate)
	templatesGroup.Post("/:id/duplicate", controllers.DuplicateTemplate)
	templatesGroup.Post("/:id/upload", controllers.UploadTemplateFile)

	departmentsGroup := router.Group("/departments", middlewares.ProtectedMiddleware())
	departmentsGroup.Get("/", controllers.GetDepartments)
	departmentsGroup.Post("/", controllers.CreateDepartment)
	departmentsGroup.Put("/:id", controllers.UpdateDepartment)
	departmentsGroup.Delete("/:id", controllers.DeleteDepartment)

	teamGroup := router.Group("/team", middlewares.ProtectedMiddleware())
	teamGroup.Get("/users", controllers.GetTeamUsers)
	teamGroup.Post("/users", controllers.CreateTeamUser)
	teamGroup.Put("/users/:id", controllers.UpdateTeamUser)
	teamGroup.Get("/users/:id/permissions", controllers.GetUserPermissions)
	teamGroup.Put("/users/:id/permissions", controllers.UpsertUserPermissions)

	integrationsGroup := router.Group("/integrations", middlewares.ProtectedMiddleware())
	integrationsGroup.Get("/documents", controllers.GetIntegrationDocuments)
	integrationsGroup.Post("/documents/:id/signers", controllers.AddIntegrationSigner)
	integrationsGroup.Delete("/documents/:id/signers/:signerId", controllers.RemoveIntegrationSigner)
	integrationsGroup.Post("/documents/:id/send", controllers.SendIntegrationDocument)

	apiKeysGroup := router.Group("/api-keys", middlewares.ProtectedMiddleware())
	apiKeysGroup.Get("/", controllers.GetApiKeys)
	apiKeysGroup.Post("/", controllers.CreateApiKey)
	apiKeysGroup.Delete("/:id", controllers.DeleteApiKey)

	webhooksGroup := router.Group("/webhooks", middlewares.ProtectedMiddleware())
	webhooksGroup.Get("/", controllers.GetWebhooks)
	webhooksGroup.Post("/", controllers.CreateWebhook)
	webhooksGroup.Put("/:id/toggle", controllers.ToggleWebhook)
	webhooksGroup.Delete("/:id", controllers.DeleteWebhook)
	// Placeholder for file download (MinIO URL or Proxy)
	// documentsGroup.Get("/download/:filename", controllers.DownloadDocumentFile)

	signingGroup := router.Group("/signing")
	signingGroup.Get("/:token", controllers.GetSignToken)
	signingGroup.Get("/:token/download", controllers.DownloadSigningDocument)
	signingGroup.Post("/:token/request-token", controllers.RequestVerificationToken)
	signingGroup.Post("/:token/verify-biometria", controllers.VerifyBiometria)
	signingGroup.Post("/:token/fields/:fieldId/sign", controllers.SignDocumentField)
	signingGroup.Post("/:token/validation-steps/:stepId/complete", controllers.CompleteValidationStep)
	signingGroup.Post("/:token/sign", controllers.SignDocument)

	valerisGroup := router.Group("/valeris")
	valerisGroup.Post("/captures", controllers.CreateValerisCapture)

	adminGroup := router.Group("/admin", middlewares.ProtectedMiddleware())
	// Middlewares.RequireSuperAdmin() would be added here
	adminGroup.Get("/companies", controllers.GetCompanies)
	adminGroup.Post("/companies", controllers.CreateCompany)
	adminGroup.Get("/companies/:id", controllers.GetCompanyDetails)
	adminGroup.Post("/companies/:id/users", controllers.AddCompanyUser)
	adminGroup.Post("/users/:id/reset_password", controllers.ResetUserPassword)
	adminGroup.Put("/users/:id", controllers.UpdateUserRoles) // For generic editing
	adminGroup.Delete("/users/:id", controllers.DeactivateUser)

	aiGroup := router.Group("/ai", middlewares.ProtectedMiddleware())
	aiGroup.Post("/chat", controllers.ProcessChat)
	aiGroup.Post("/embeddings/process", controllers.ProcessEmbeddings)
	router.Get("/health/embeddings", controllers.HealthEmbeddings)

	// Placeholder Routes
	router.Get("/ping", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"message": "pong"})
	})
}
