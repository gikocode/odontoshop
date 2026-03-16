const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';

// 1. Interfaces de datos (Basadas en tu estructura de Go)
export interface User {
  id: string;
  email: string;
  user_type: 'employee' | 'customer';
  status: string;
  employee?: {
    id: string;
    first_name: string;
    last_name: string;
    position: string;
  };
  roles: Array<{
    id: string;
    name: string;
    display_name: string;
  }>;
}

export interface LoginResponse {
  user: User;
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

// 2. Objeto de servicio centralizado
export const authService = {
  
  // Iniciar sesión
  login: async (email: string, password: string): Promise<LoginResponse> => {
    const response = await fetch(`${API_URL}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Error al iniciar sesión');
    }

    const data = await response.json();
    
    // Guardar en almacenamiento local
    if (typeof window !== 'undefined') {
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      localStorage.setItem('user', JSON.stringify(data.user));
    }
    
    return data;
  },

  // Cerrar sesión
  logout: async (): Promise<void> => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('access_token') : null;
    
    if (token) {
      try {
        await fetch(`${API_URL}/api/auth/logout`, {
          method: 'POST',
          headers: { 'Authorization': `Bearer ${token}` },
        });
      } catch (e) {
        console.error("Error notificando logout al servidor", e);
      }
    }
    
    if (typeof window !== 'undefined') {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
  },

  // Obtener lista de usuarios (Para el Dashboard)
  getUsers: async (): Promise<User[]> => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('access_token') : null;
    
    const response = await fetch(`${API_URL}/api/admin/users`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'No se pudo obtener la lista de usuarios');
    }

    return await response.json();
  },

  // Obtener datos del usuario actual desde la API
  getCurrentUser: async (): Promise<User> => {
    const token = typeof window !== 'undefined' ? localStorage.getItem('access_token') : null;
    if (!token) throw new Error('No hay sesión activa');
    
    const response = await fetch(`${API_URL}/api/auth/me`, {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    
    if (!response.ok) throw new Error('Sesión inválida');
    return await response.json();
  },

  // Helpers para obtener datos guardados rápidamente
  getStoredUser: (): User | null => {
    if (typeof window !== 'undefined') {
      const userStr = localStorage.getItem('user');
      return userStr ? JSON.parse(userStr) : null;
    }
    return null;
  },

  getStoredToken: (): string | null => {
    if (typeof window !== 'undefined') {
      return localStorage.getItem('access_token');
    }
    return null;
  }
};