'use client';
import { useState } from 'react';
import { authService } from '@/services/authService';
import { useRouter } from 'next/navigation';

export default function LoginForm() {
  const [email, setEmail] = useState('admin@odontoshop.com');
  const [password, setPassword] = useState('admin123');
  const [error, setError] = useState('');
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await authService.login(email, password);
      alert('¡Login Exitoso!');
      router.push('/dashboard');
    } catch (err: any) {
      setError(err.response?.data?.error || 'Error al conectar con el servidor');
    }
  };

  return (
    <form onSubmit={handleSubmit} className="p-8 bg-white shadow-md rounded-lg max-w-sm mx-auto mt-20">
      <h2 className="text-2xl font-bold mb-6 text-gray-800">Admin Login</h2>
      {error && <p className="text-red-500 mb-4">{error}</p>}
      <input 
        type="email" 
        value={email} 
        onChange={(e) => setEmail(e.target.value)}
        className="w-full p-2 mb-4 border rounded text-black" 
        placeholder="Email"
      />
      <input 
        type="password" 
        value={password} 
        onChange={(e) => setPassword(e.target.value)}
        className="w-full p-2 mb-6 border rounded text-black" 
        placeholder="Password"
      />
      <button type="submit" className="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700">
        Entrar
      </button>
    </form>
  );
}