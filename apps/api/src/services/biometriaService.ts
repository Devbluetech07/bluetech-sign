import axios from 'axios';

const BLUEPOINT_URL = process.env.BLUEPOINT_API_URL || 'https://bluepoint-api.bluetechfilms.com.br';
const BLUEPOINT_KEY = process.env.BLUEPOINT_API_KEY || '';

const api = axios.create({
  baseURL: BLUEPOINT_URL,
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${BLUEPOINT_KEY}`,
    'x-api-key': BLUEPOINT_KEY,
  },
  timeout: 30000,
});

export interface BiometriaResult {
  success: boolean;
  score?: number;
  verified?: boolean;
  message?: string;
  externalId?: string;
}

// Cadastrar face para reconhecimento facial
export async function cadastrarFace(imageBase64: string, externalId: string, nome: string, cpf?: string): Promise<BiometriaResult> {
  try {
    const response = await api.post('/api/v1/biometria/cadastrar-face', {
      image: imageBase64,
      externalId,
      nome,
      cpf,
    });
    return {
      success: true,
      externalId: response.data.externalId || externalId,
      message: 'Face cadastrada com sucesso',
    };
  } catch (error: any) {
    console.error('Erro ao cadastrar face:', error.response?.data || error.message);
    return { success: false, message: error.response?.data?.message || 'Erro ao cadastrar face' };
  }
}

// Cadastrar face via CPF
export async function cadastrarFaceCpf(imageBase64: string, cpf: string): Promise<BiometriaResult> {
  try {
    const response = await api.post('/api/v1/biometria/cadastrar-face-cpf', {
      image: imageBase64,
      cpf,
    });
    return { success: true, message: 'Face cadastrada via CPF com sucesso' };
  } catch (error: any) {
    return { success: false, message: error.response?.data?.message || 'Erro ao cadastrar face via CPF' };
  }
}

// Verificar/autenticar face
export async function verificarFace(imageBase64: string, externalId: string): Promise<BiometriaResult> {
  try {
    const response = await api.post('/api/v1/biometria/verificar-face', {
      image: imageBase64,
      externalId,
    });
    return {
      success: true,
      verified: response.data.verified ?? response.data.match ?? true,
      score: response.data.score ?? response.data.confidence ?? 0,
      message: response.data.message || 'Verificação realizada',
    };
  } catch (error: any) {
    return { success: false, verified: false, score: 0, message: error.response?.data?.message || 'Erro na verificação facial' };
  }
}

// Status da biometria por ID externo
export async function statusBiometriaExterna(externalId: string): Promise<BiometriaResult> {
  try {
    const response = await api.get(`/api/v1/biometria/status-externo/${externalId}`);
    return { success: true, message: response.data.status || 'ativa' };
  } catch (error: any) {
    return { success: false, message: error.response?.data?.message || 'Biometria não encontrada' };
  }
}

// Remover face por ID externo
export async function removerFaceExterna(externalId: string): Promise<BiometriaResult> {
  try {
    await api.delete('/api/v1/biometria/remover-face-externa', { data: { externalId } });
    return { success: true, message: 'Face removida com sucesso' };
  } catch (error: any) {
    return { success: false, message: error.response?.data?.message || 'Erro ao remover face' };
  }
}

export function isConfigured(): boolean {
  return !!BLUEPOINT_KEY && BLUEPOINT_KEY.length > 0;
}
