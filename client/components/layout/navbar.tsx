"use client"

import { useState } from "react"
import Link from "next/link"
import { Menu, X } from "lucide-react"
import { Button } from "@/components/ui/button"
import { ConnectButton, useActiveAccount } from "thirdweb/react"
import { client, mantleSepolia, wallets } from "@/lib/thirdweb"

export default function Navbar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const account = useActiveAccount()

  const navLinks = [
    { label: "Explore", href: "/explore" },
    { label: "Create Bet", href: "/create" },
    { label: "My Bets", href: "/my-bets" },
    { label: "Pools", href: "/pools" },
    { label: "Judges", href: "/judges" },
  ]

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
          <div className="hidden sm:block">
            <ConnectButton
              client={client}
              wallets={wallets}
              chain={mantleSepolia}
              theme="dark"
              connectButton={{
                label: "Connect Wallet",
                className: "!bg-transparent !border !border-neutral-700 !text-neutral-100 hover:!border-orange-500 hover:!text-orange-500 !transition-colors",
              }}
              detailsButton={{
                className: "!bg-transparent !border !border-neutral-700 !text-neutral-100 hover:!border-orange-500 !transition-colors",
              }}
            />
          </div>
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
            <div className="mt-4">
              <ConnectButton
                client={client}
                wallets={wallets}
                chain={mantleSepolia}
                theme="dark"
                connectButton={{
                  label: "Connect Wallet",
                  className: "!w-full",
                }}
              />
            </div>
          </div>
        </div>
      )}
    </nav>
  )
}
