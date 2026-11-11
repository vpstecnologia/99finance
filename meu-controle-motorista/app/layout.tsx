import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Meu Controle Motorista', description: 'Gestão financeira para motoristas de aplicativo' };
export default function Layout({children}:{children:React.ReactNode}) { return <html lang="pt-BR"><body>{children}</body></html> }
