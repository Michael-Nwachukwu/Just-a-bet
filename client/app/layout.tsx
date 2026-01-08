import type React from "react"
import type { Metadata } from "next"
import { Space_Mono as SpaceMono } from "next/font/google"
import "./globals.css"
import Navbar from "@/components/layout/navbar"
import Footer from "@/components/layout/footer"
import { Providers } from "./providers"

const spaceMono = SpaceMono({
  weight: ["400", "700"],
  subsets: ["latin"],
  variable: "--font-space-mono",
})

export const metadata: Metadata = {
  title: "Just-a-Bet - P2P Betting Platform",
  description: "Decentralized peer-to-peer betting platform with AI-powered risk assessment",
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className={`${spaceMono.className} ${spaceMono.variable}`}>
      <body className="bg-black text-white antialiased">
        <Providers>
          <Navbar />
          {children}
          <Footer />
        </Providers>
      </body>
    </html>
  )
}
