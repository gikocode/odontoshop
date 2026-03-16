'use client';
import { useEffect, useState } from 'react';
import { authService, LoginResponse } from '@/services/authService';
import { useRouter } from 'next/navigation';

// Definimos la interfaz basada en lo que Go devuelve según tu authService
interface UserDetail {
  id: string;
  email: string;
  user_type: 'employee' | 'customer';
  status: string;
  roles: Array<{
    id: string;
    name: string;
    display_name: string;
  }>;
}

export default function DashboardPage() {
  const [users, setUsers] = useState<UserDetail[]>([]);
  const [currentUser, setCurrentUser] = useState<LoginResponse['user'] | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    const initDashboard = async () => {
      try {
        // 1. Verificar si hay usuario en sesión
        const user = authService.getStoredUser();
        if (!user) {
          router.push('/login');
          return;
        }
        setCurrentUser(user);

        // 2. Cargar usuarios desde el Backend
        // Nota: Asegúrate de haber agregado 'getUsers' a tu authService
        const data = await authService.getUsers();
        setUsers(data);
      } catch (err) {
        console.error("Error al cargar dashboard:", err);
      } finally {
        setLoading(false);
      }
    };

    initDashboard();
  }, [router]);

  const handleLogout = () => {
    authService.logout();
  };

  if (loading) return (
    <div className="flex h-screen items-center justify-center bg-gray-100">
      <p className="text-gray-600 animate-pulse">Cargando panel de administración...</p>
    </div>
  );

  return (
    <div className="flex h-screen bg-gray-100 text-gray-800">
      
      {/* SIDEBAR LATERAL */}
      <aside className="w-64 bg-indigo-900 text-white flex flex-col">
        <div className="p-6 text-2xl font-bold border-b border-indigo-800 text-center">
          OdontoShop
        </div>
        <nav className="flex-1 p-4 space-y-2">
          <a href="#" className="block py-2.5 px-4 rounded bg-indigo-800 transition">Usuarios</a>
          <a href="#" className="block py-2.5 px-4 rounded hover:bg-indigo-800 transition">Inventario</a>
          <a href="#" className="block py-2.5 px-4 rounded hover:bg-indigo-800 transition">Ventas</a>
          <a href="#" className="block py-2.5 px-4 rounded hover:bg-indigo-800 transition">Configuración</a>
        </nav>
        <div className="p-4 border-t border-indigo-800">
          <button 
            onClick={handleLogout}
            className="w-full bg-red-500 hover:bg-red-600 py-2 rounded text-sm font-semibold transition"
          >
            Cerrar Sesión
          </button>
        </div>
      </aside>

      {/* CONTENIDO PRINCIPAL */}
      <main className="flex-1 overflow-y-auto p-8">
        <header className="flex justify-between items-center mb-8 bg-white p-6 rounded-xl shadow-sm border border-gray-200">
          <div>
            <h1 className="text-2xl font-bold">Panel de Usuarios</h1>
            <p className="text-sm text-gray-500">Bienvenido, {currentUser?.email}</p>
          </div>
          <button className="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition">
            + Nuevo Usuario
          </button>
        </header>

        {/* TABLA DE USUARIOS */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Tipo</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Roles</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Estado</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Acciones</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {users.length > 0 ? users.map((u) => (
                <tr key={u.id} className="hover:bg-gray-50 transition">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">{u.email}</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm capitalize">
                    {u.user_type === 'employee' ? '💼 Empleado' : '🛒 Cliente'}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex gap-1">
                      {u.roles?.map(role => (
                        <span key={role.id} className="bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded text-[10px] font-bold uppercase">
                          {role.display_name}
                        </span>
                      ))}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm">
                    <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                      u.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                    }`}>
                      {u.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <button className="text-indigo-600 hover:text-indigo-900 mr-3">Editar</button>
                    <button className="text-red-600 hover:text-red-900">Eliminar</button>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan={5} className="px-6 py-10 text-center text-gray-400">
                    No se encontraron usuarios en la base de datos.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </main>
    </div>
  );
}