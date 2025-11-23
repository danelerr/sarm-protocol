"use client"

import { motion } from "framer-motion"
import { Twitter, Github, MessageCircle, FileText } from "lucide-react"
import Image from "next/image"

export function Footer() {
  const currentYear = new Date().getFullYear()

  const socialLinks = [
    { icon: Twitter, href: "#", label: "Twitter" },
    { icon: Github, href: "#", label: "GitHub" },
    { icon: MessageCircle, href: "#", label: "Discord" },
    { icon: FileText, href: "#", label: "Docs" },
  ]

  return (
    <footer className="relative z-10 mt-20 border-t border-border/50">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="grid md:grid-cols-3 gap-8 items-center">
          {/* Logo & Description */}
          <div className="space-y-3">
            <div className="flex items-center gap-2">
              <Image src="/sage-logo.svg" alt="SAGE Protocol" width={30} height={27} />
              <span className="text-xl font-bold sage-gradient-text">SAGE Protocol</span>
            </div>
            <p className="text-sm text-muted-foreground">Next-generation DeFi with intelligent fee optimization</p>
          </div>

          {/* Social Links */}
          <div className="flex justify-center gap-4">
            {socialLinks.map((link, index) => (
              <motion.a
                key={link.label}
                href={link.href}
                whileHover={{ scale: 1.1, y: -2 }}
                whileTap={{ scale: 0.95 }}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.1 }}
                className="p-3 rounded-xl sage-glass hover:bg-primary/10 transition-colors"
                aria-label={link.label}
              >
                <link.icon className="w-5 h-5 text-muted-foreground hover:text-primary transition-colors" />
              </motion.a>
            ))}
          </div>

          {/* Copyright */}
          <div className="text-center md:text-right">
            <p className="text-sm text-muted-foreground">© {currentYear} SAGE Protocol. All rights reserved.</p>
          </div>
        </div>
      </div>
    </footer>
  )
}
