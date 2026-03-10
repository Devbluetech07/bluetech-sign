/**
 * Valeris SDK v2.2
 * Microsserviços de Captura de Identidade & Assinatura
 * Coleta de metadados enriquecidos + comunicação com API REST
 */

const ValerisSDK = {
    config: {
        apiUrl: "/api",
        token: "portal-demo", // Default token for portal testing
    },

    init: function(options) {
        console.log("ValerisSDK: Initializing with", options);
        if (options?.apiUrl) ValerisSDK.config.apiUrl = options.apiUrl;
        if (options?.token) ValerisSDK.config.token = options.token;
        // Keep safe defaults even if init is called with partial/empty options.
        if (!ValerisSDK.config.apiUrl) ValerisSDK.config.apiUrl = "/api";
        if (!ValerisSDK.config.token) ValerisSDK.config.token = "portal-demo";
    },

    // ==========================================
    // 1. DADOS DE DISPOSITIVO E GEOLOCALIZAÇÃO
    // ==========================================
    _deviceInfo: null,

    getDeviceInfo: async function() {
        if (this._deviceInfo) return this._deviceInfo;

        let ip_publico = "Desconhecido";
        try {
            const res = await fetch('https://api.ipify.org?format=json');
            const data = await res.json();
            ip_publico = data.ip;
        } catch(e) { console.warn("Erro ao obter IP público", e); }

        const ua = navigator.userAgent;
        let navegador = "Desconhecido";
        if(ua.includes("Edg")) navegador = "Edge";
        else if(ua.includes("Chrome")) navegador = "Chrome";
        else if(ua.includes("Firefox")) navegador = "Firefox";
        else if(ua.includes("Safari") && !ua.includes("Chrome")) navegador = "Safari";

        let sistema_operacional = "Desconhecido";
        if(ua.includes("Windows")) sistema_operacional = "Windows";
        else if(ua.includes("Mac OS")) sistema_operacional = "Mac OS";
        else if(ua.includes("Linux")) sistema_operacional = "Linux";
        else if(ua.includes("Android")) sistema_operacional = "Android";
        else if(ua.includes("iOS") || ua.includes("iPhone")) sistema_operacional = "iOS";

        const now = new Date();

        this._deviceInfo = {
            ip_publico,
            user_agent: ua,
            navegador,
            sistema_operacional,
            plataforma: navigator.platform,
            idioma: navigator.language,
            resolucao_tela: `${window.screen.width}x${window.screen.height}`,
            fuso_horario: Intl.DateTimeFormat().resolvedOptions().timeZone,
            data_hora: now.toISOString(),
            data_hora_local: now.toLocaleString('pt-BR'),
        };
        return this._deviceInfo;
    },

    getGeolocation: async function() {
        return new Promise((resolve) => {
            if (!("geolocation" in navigator)) {
                resolve({ latitude: null, longitude: null, endereco: "Geolocalização não suportada" });
                return;
            }
            navigator.geolocation.getCurrentPosition(async (pos) => {
                const lat = pos.coords.latitude;
                const lng = pos.coords.longitude;
                const accuracy = typeof pos.coords.accuracy === "number" ? Math.round(pos.coords.accuracy) : null;
                let endereco = "Endereço não resolvido";
                try {
                    const res = await fetch(`https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json&zoom=18&addressdetails=1&namedetails=1&accept-language=pt-BR`);
                    if (res.ok) {
                        const d = await res.json();
                        if (d?.display_name) endereco = d.display_name;
                    }
                } catch(e) {
                    // ignore and try fallback provider below
                }

                if (endereco === "Endereço não resolvido") {
                    try {
                        const fallback = await fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lng}&localityLanguage=pt`);
                        if (fallback.ok) {
                            const fd = await fallback.json();
                            const parts = [
                                fd.locality,
                                fd.principalSubdivision,
                                fd.countryName
                            ].filter(Boolean);
                            if (parts.length) endereco = parts.join(", ");
                        }
                    } catch(e) {
                        // keep default address text
                    }
                }

                resolve({
                    latitude: lat,
                    longitude: lng,
                    endereco,
                    precisao_metros: accuracy
                });
            }, () => {
                resolve({ latitude: null, longitude: null, endereco: "Permissão de localização negada" });
            }, { timeout: 15000, enableHighAccuracy: true, maximumAge: 0 });
        });
    },

    // ==========================================
    // 2. HEURÍSTICAS DE VALIDAÇÃO DE IMAGEM
    // ==========================================
    validation: {
        _getImageData: function(dataUrl) {
            return new Promise((resolve) => {
                const img = new Image();
                img.onload = () => {
                    const canvas = document.createElement('canvas');
                    canvas.width = 640; canvas.height = 480;
                    const ctx = canvas.getContext('2d');
                    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                    resolve(ctx.getImageData(0, 0, canvas.width, canvas.height));
                };
                img.src = dataUrl;
            });
        },

        face: async function(dataUrl) {
            const imageData = await this._getImageData(dataUrl);
            const { data, width, height } = imageData;
            const totalPixels = width * height;
            let skinPixels = 0, brightnessSum = 0, contrastSum = 0, saturationSum = 0;
            for (let i = 0; i < data.length; i += 4) {
                const r = data[i], g = data[i+1], b = data[i+2];
                const y = 0.299*r + 0.587*g + 0.114*b;
                const cb = 128 - 0.168736*r - 0.331264*g + 0.5*b;
                const cr = 128 + 0.5*r - 0.418688*g - 0.081312*b;
                brightnessSum += y;
                if (cb > 77 && cb < 127 && cr > 133 && cr < 173) skinPixels++;
                if (i > 0) contrastSum += Math.abs(y - (0.299*data[i-4] + 0.587*data[i-3] + 0.114*data[i-2]));
                saturationSum += (Math.max(r, g, b) - Math.min(r, g, b));
            }
            const avgBrightness = brightnessSum / totalPixels;
            const avgContrast = contrastSum / totalPixels;
            const avgSaturation = saturationSum / totalPixels;
            const skinPercentage = (skinPixels / totalPixels) * 100;
            
            let confidence = Math.min(100, skinPercentage * 5.5);
            if (avgBrightness < 45 || avgBrightness > 215) confidence -= 25;
            if (avgContrast < 4) confidence -= 20;
            if (avgSaturation < 10) confidence -= 30;
            
            const isValid = confidence >= 60;
            return { isValid, confidence: Math.max(0, Math.round(confidence)), reasons: isValid ? [] : ["Identificação facial incerta"] };
        },

        document: async function(dataUrl, expectedType = 'ID') {
            const imageData = await this._getImageData(dataUrl);
            const { data, width, height } = imageData;
            const totalPixels = width * height;
            const step = 2;
            
            let edgePixels = 0;
            let greenishPixels = 0;
            let saturationSum = 0;
            for (let y = 1; y < height - 1; y += step) {
                for (let x = 1; x < width - 1; x += step) {
                    const idx = (y * width + x) * 4;
                    const r = data[idx], g = data[idx+1], b = data[idx+2];
                    const val = (r + g + b) / 3;
                    const prevX = (y * width + (x - 1)) * 4;
                    const valPrevX = (data[prevX] + data[prevX+1] + data[prevX+2]) / 3;
                    if (Math.abs(val - valPrevX) > 15) edgePixels++;
                    if (g > r * 1.08 && g > b * 1.05 && (g - r) > 8) greenishPixels++;
                    saturationSum += (Math.max(r, g, b) - Math.min(r, g, b));
                }
            }
            
            const sampledPixels = totalPixels / (step * step);
            const density = (edgePixels / sampledPixels) * 100;
            const greenRatio = greenishPixels / sampledPixels;
            const avgSaturation = saturationSum / sampledPixels;
            const longSide = Math.max(width, height);
            const shortSide = Math.min(width, height);
            const ratio = longSide / shortSide;
            
            let cnhScore = 0;
            let idScore = 0;
            let passportScore = 0;

            // CNH usually appears landscape and greener in Brazil.
            if (ratio > 1.45 && ratio < 1.85) cnhScore += 30;
            if (greenRatio > 0.11) cnhScore += 35;
            if (avgSaturation > 30) cnhScore += 10;
            if (density > 1.2) cnhScore += 10;

            // RG/ID usually has lower green dominance and different visual profile.
            if (ratio > 1.2 && ratio < 1.65) idScore += 25;
            if (greenRatio < 0.08) idScore += 25;
            if (avgSaturation < 32) idScore += 10;
            if (density > 1.0) idScore += 10;

            // Passport is usually more compact and less green dominant.
            if (ratio > 1.2 && ratio < 1.55) passportScore += 20;
            if (greenRatio < 0.06) passportScore += 15;
            if (avgSaturation < 26) passportScore += 15;

            let detectedType = "ID";
            if (cnhScore >= idScore && cnhScore >= passportScore) detectedType = "CNH";
            else if (passportScore > cnhScore && passportScore > idScore) detectedType = "PASSPORT";

            let confidence = Math.min(100, density * 18);
            if (detectedType === "CNH" && greenRatio > 0.11) confidence += 15;
            if (detectedType === "ID" && greenRatio < 0.08) confidence += 10;
            let isValid = confidence > 25; 
            const reasons = [];

            if (density < 1.0) {
                isValid = false;
                reasons.push("Baixa qualidade de captura");
            }
            
            if (expectedType && expectedType !== 'ANY') {
                const match = (expectedType === 'ID' && (detectedType === 'ID')) ||
                              (expectedType === 'CNH' && detectedType === 'CNH') ||
                              (expectedType === 'PASSPORT' && detectedType === 'PASSPORT');
                
                if (!match && confidence < 50) {
                    isValid = false;
                    reasons.push(`Tipo divergente (${detectedType})`);
                }
            }

            return { 
                isValid, 
                detectedType, 
                confidence: Math.round(confidence),
                reasons: isValid ? [] : (reasons.length ? reasons : ["Enquadre melhor"])
            };
        },

        selfieWithDocument: async function(dataUrl) {
            const faceResult = await this.face(dataUrl);
            const docResult = await this.document(dataUrl);
            const confidence = (faceResult.confidence * 0.6) + (docResult.confidence * 0.4);
            const isValid = confidence >= 45;
            const reasons = [];
            if(!isValid) {
                if(faceResult.confidence < 40) reasons.push("Rosto não detectado.");
                if(docResult.confidence < 25) reasons.push("Documento não legível.");
            }
            return { isValid, confidence: Math.round(confidence), reasons };
        }
    },

    // ==========================================
    // 3. GERAÇÃO DE IMAGEM COMPOSTA COM METADADOS
    // ==========================================
    generateComposite: async function(images, metadata) {
        return new Promise((resolve) => {
            const canvas = document.createElement('canvas');
            canvas.width = 800;

            Promise.all(images.map(imgData => {
                return new Promise(r => {
                    const img = new Image();
                    img.onload = () => r({ label: imgData.label, img });
                    img.src = imgData.dataUrl;
                });
            })).then(loadedImages => {
                let totalImageHeight = 0;
                const aspectRatios = [];
                loadedImages.forEach(item => {
                    const ratio = item.img.height / item.img.width;
                    const scaledHeight = (canvas.width - 40) * ratio;
                    aspectRatios.push(scaledHeight);
                    totalImageHeight += scaledHeight + 60;
                });

                const metaBoxX = 30;
                const metaBoxWidth = canvas.width - 60; // same width as photos
                const metaPaddingX = 14;
                const metaHeaderTop = 28;
                const metaStartY = 54;
                const metaLineHeight = 22;
                const metaMaxTextWidth = metaBoxWidth - (metaPaddingX * 2);

                const measureCanvas = document.createElement('canvas');
                const measureCtx = measureCanvas.getContext('2d');
                measureCtx.font = '12px Inter';

                const baseLines = [
                    `Data/Hora: ${metadata.data_hora_local || new Date().toLocaleString('pt-BR')}`,
                    `IP Publico: ${metadata.ip_publico || 'N/A'}`,
                    `Localizacao: ${metadata.endereco || 'N/A'}`,
                    `Lat: ${metadata.latitude || 'N/A'}  Lon: ${metadata.longitude || 'N/A'}`,
                    `Sistema: ${metadata.navegador || 'N/A'} / ${metadata.sistema_operacional || 'N/A'}`,
                    `Fuso: ${metadata.fuso_horario || 'N/A'}`,
                    `Resolucao: ${metadata.resolucao_tela || 'N/A'}`,
                ];

                const wrapLine = (ctx, text, maxWidth) => {
                    const words = String(text || '').split(' ');
                    const lines = [];
                    let current = '';
                    for (const word of words) {
                        const probe = current ? `${current} ${word}` : word;
                        if (ctx.measureText(probe).width <= maxWidth) {
                            current = probe;
                        } else {
                            if (current) lines.push(current);
                            current = word;
                        }
                    }
                    if (current) lines.push(current);
                    return lines.length ? lines : ['-'];
                };

                const wrappedLines = [];
                baseLines.forEach(line => {
                    wrapLine(measureCtx, line, metaMaxTextWidth).forEach(w => wrappedLines.push(w));
                });

                const metadataHeight = Math.max(190, metaStartY + (wrappedLines.length * metaLineHeight) + 18);
                canvas.height = totalImageHeight + metadataHeight;
                const ctx = canvas.getContext('2d');
                ctx.fillStyle = '#0A111F';
                ctx.fillRect(0, 0, canvas.width, canvas.height);

                let currentY = 30;
                loadedImages.forEach((item, index) => {
                    ctx.fillStyle = '#00FF88';
                    ctx.font = 'bold 18px Inter, sans-serif';
                    ctx.fillText(item.label, 30, currentY + 18);
                    currentY += 36;
                    ctx.drawImage(item.img, 30, currentY, canvas.width - 60, aspectRatios[index]);
                    currentY += aspectRatios[index] + 20;
                });

                const metaY = canvas.height - metadataHeight - 10;
                ctx.fillStyle = '#0d1a2d';
                ctx.fillRect(metaBoxX, metaY, metaBoxWidth, metadataHeight);
                ctx.strokeStyle = '#00FF88';
                ctx.strokeRect(metaBoxX, metaY, metaBoxWidth, metadataHeight);

                ctx.fillStyle = '#00FF88';
                ctx.font = 'bold 14px Inter';
                ctx.fillText(`Valeris KYC — ${metadata.serviceType || 'Captura'}`, metaBoxX + metaPaddingX, metaY + metaHeaderTop);

                ctx.font = '12px Inter';
                ctx.fillStyle = '#808FA3';
                wrappedLines.forEach((line, i) => {
                    ctx.fillText(line, metaBoxX + metaPaddingX, metaY + metaStartY + (i * metaLineHeight));
                });

                resolve(canvas.toDataURL('image/jpeg', 0.88));
            });
        });
    },

    submitCapture: async function(serviceType, imageDataUrl, metadata = {}) {
        console.log("ValerisSDK: Submitting capture", serviceType);
        const cfg = ValerisSDK.config || {};
        const apiUrl = cfg.apiUrl || "/api";
        const token = cfg.token || "portal-demo";

        if (!apiUrl || !token) {
            console.error("ValerisSDK: Missing config", cfg);
            throw new Error("SDK não inicializado (apiUrl ou token ausentes)");
        }
        
        const payload = {
            service_type: serviceType,
            image_data: imageDataUrl,
            metadata: metadata
        };

        const response = await fetch(`${apiUrl}/captures`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const raw = await response.text();
            let message = "Erro ao enviar captura";
            try {
                const err = JSON.parse(raw);
                if (err?.message) message = err.message;
                else if (typeof err === "string" && err.trim()) message = err;
            } catch (_) {
                if (raw && raw.trim()) {
                    const cleaned = raw.replace(/\s+/g, " ").trim();
                    if (cleaned.startsWith("<!DOCTYPE") || cleaned.startsWith("<html")) {
                        message = "Falha de integração API/proxy. Verifique token e rota /api.";
                    } else {
                        message = cleaned.slice(0, 180);
                    }
                }
            }
            throw new Error(message);
        }

        const result = await response.json();
        
        if (window.parent && window.parent !== window) {
            window.parent.postMessage({
                type: 'VALERIS_CAPTURE_SUCCESS',
                serviceType: serviceType,
                captureId: result.id
            }, '*');
        }

        return result;
    }
};

window.ValerisSDK = ValerisSDK;
