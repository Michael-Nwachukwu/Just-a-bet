"use client"

import { useState } from "react"
import Link from "next/link"
import { Menu, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { useAppKit } from "@reown/appkit/react"
import { useAccount } from "wagmi"

export default function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const { open } = useAppKit()
  const { address, isConnected } = useAccount()

  const navLinks = [
    { label: "Explore", href: "/explore" },
    { label: "Create Bet", href: "/create" },
    { label: "My Bets", href: "/my-bets" },
    { label: "Pools", href: "/pools" },
  ]

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`
  }

  return (
    <nav className="fixed top-0 w-full bg-neutral-950 border-b border-orange-500/20 z-50">
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        {/* Logo */}
        <Link href="/" className="flex items-center gap-2">
          <div className="text-2xl font-bold">
            <span className="text-orange-500">JUST</span>
            <span className="text-cyan-400">-A-</span>
            <span className="text-orange-500">BET</span>
          </div>
        </Link>

        {/* Desktop Navigation */}
        <div className="hidden md:flex items-center gap-8">
          {navLinks.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="text-neutral-400 hover:text-orange-500 transition-colors text-sm font-medium uppercase tracking-wide"
            >
              {link.label}
            </Link>
          ))}
        </div>

        {/* Right Section */}
        <div className="flex items-center gap-4">
          <Button
            variant="outline"
            className="hidden sm:inline-flex bg-transparent"
            onClick={() => open()}
          >
            {isConnected && address ? formatAddress(address) : "Connect Wallet"}
          </Button>
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden text-orange-500 hover:bg-neutral-800"
          >
            {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </Button>
        </div>
      </div>

      {/* Mobile Menu */}
      {mobileMenuOpen && (
        <div className="md:hidden bg-neutral-900 border-b border-orange-500/20">
          <div className="px-6 py-4 space-y-3">
            {navLinks.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="block text-neutral-400 hover:text-orange-500 transition-colors text-sm font-medium uppercase tracking-wide py-2"
                onClick={() => setMobileMenuOpen(false)}
              >
                {link.label}
              </Link>
            ))}
            <Button className="w-full mt-4" onClick={() => open()}>
              {isConnected && address ? formatAddress(address) : "Connect Wallet"}
            </Button>
          </div>
        </div>
      )}
    </nav>
  )
}
