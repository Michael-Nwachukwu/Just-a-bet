import Link from "next/link"
import { Github, Twitter, MessageCircle } from "lucide-react"

export default function Footer() {
  return (
    <footer className="bg-neutral-950 border-t border-orange-500/20 py-12">
      <div className="max-w-7xl mx-auto px-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 mb-8">
          {/* About */}
          <div>
            <div className="text-lg font-bold mb-4">
              <span className="text-orange-500">JUST</span>
              <span className="text-cyan-400">-A-</span>
              <span className="text-orange-500">BET</span>
            </div>
            <p className="text-neutral-400 text-sm mb-4">Decentralized peer-to-peer betting platform</p>
            <div className="flex gap-4">
              <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                <Twitter className="w-5 h-5" />
              </Link>
              <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                <MessageCircle className="w-5 h-5" />
              </Link>
              <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                <Github className="w-5 h-5" />
              </Link>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="font-bold mb-4 uppercase text-sm tracking-wide">Quick Links</h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  Documentation
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  How It Works
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  FAQ
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  Terms of Service
                </Link>
              </li>
            </ul>
          </div>

          {/* Community */}
          <div>
            <h3 className="font-bold mb-4 uppercase text-sm tracking-wide">Community</h3>
            <ul className="space-y-2 text-sm">
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  Discord
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  Twitter
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  GitHub
                </Link>
              </li>
              <li>
                <Link href="#" className="text-neutral-400 hover:text-orange-500 transition-colors">
                  Support
                </Link>
              </li>
            </ul>
          </div>
        </div>

        <div className="border-t border-orange-500/20 pt-8">
          <p className="text-neutral-500 text-sm text-center">© 2025 Just-a-Bet. All rights reserved.</p>
        </div>
      </div>
    </footer>
  )
}
