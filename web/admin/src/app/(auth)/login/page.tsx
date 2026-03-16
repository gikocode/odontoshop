'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation'; 
import { authService } from '@/services/authService';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@odontoshop.com'); // Pre-llenado para testing
  const [password, setPassword] = useState('admin123'); // Pre-llenado para testing
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      console.log('🔐 Intentando login...', { email });
      
      const response = await authService.login(email, password);

      console.log('✅ Login exitoso:', response);
      
      // Verificar que sea empleado
      if (response.user.user_type !== 'employee') {
        setError('Solo empleados pueden acceder al panel de administración');
        return;
      }
      
      // Redirigir al dashboard
      router.push('/dashboard');
    } catch (err: any) {
      console.error('❌ Error en login:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full space-y-8 p-8 bg-white rounded-lg shadow">
        <div>
          <h2 className="text-center text-3xl font-bold text-gray-900">
            OdontoShop Admin
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Inicia sesión con tu cuenta de empleado
          </p>
        </div>
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded">
              {error}
            </div>
          )}
          
          <div className="space-y-4">
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-gray-700">
                Email
              </label>
              <input
                id="email"
                name="email"
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
                placeholder="admin@odontoshop.com"
              />
            </div>
            
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700">
                Contraseña
              </label>
              <input
                id="password"
                name="password"
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 text-gray-900"
                placeholder="••••••••"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
          >
            {loading ? 'Iniciando sesión...' : 'Iniciar Sesión'}
          </button>
        </form>
        
        {/* Info de prueba */}
        <div className="mt-4 p-4 bg-blue-50 rounded text-sm text-blue-800">
          <p className="font-semibold">Credenciales de prueba:</p>
          <p>Email: admin@odontoshop.com</p>
          <p>Password: admin123</p>
        </div>
      </div>
    </div>
  );
}