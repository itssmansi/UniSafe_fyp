"use client";

import React, { useState } from "react";
import { motion, AnimatePresence, type Variants } from "motion/react";
import { ArrowRight, ArrowDown, Play, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export interface NavLink {
    label: string;
    href: string;
    active?: boolean;
    hasDropdown?: boolean;
    dropdownItems?: { label: string; href: string }[];
}

export interface SocialLink {
    label: string;
    href: string;
}

export interface Hero2Props {
    brand?: React.ReactNode;
    navLinks?: NavLink[];
    headline?: React.ReactNode;
    description?: string;
    primaryCtaLabel?: string;
    primaryCtaHref?: string;
    secondaryCtaLabel?: string;
    secondaryCtaHref?: string;
    socialLinks?: SocialLink[];
    headerActions?: React.ReactNode;
    signInLabel?: string;
    signInHref?: string;
    className?: string;
}

const DEFAULT_NAV: NavLink[] = [
    { label: "Home", href: "/", active: true },
    { label: "Kanban", href: "/kanban" },
    { label: "Map", href: "/map" },
    { label: "Verification", href: "/verify" },
    { label: "Pricing", href: "#" },
    { label: "About", href: "#" },
    { label: "FAQs", href: "#" },
];

const DEFAULT_SOCIAL: SocialLink[] = [
    { label: "LinkedIn", href: "https://linkedin.com/company/watermelon" },
    { label: "Twitter", href: "https://twitter.com/watermelon" },
    { label: "GitHub", href: "https://github.com/watermelon" },
];

export function Hero2({
    brand = "Watermelon",
    navLinks = DEFAULT_NAV,
    headline = (
        <>
            Automate Smarter,<br />
            Work <span className="italic font-medium font-serif text-unisafe-teal">Faster.</span>
        </>
    ),
    description = "Say goodbye to repetitive tasks. Our AI-driven platform streamlines\nyour workflows so your team can focus on what really matters.",
    primaryCtaLabel = "See It In Action",
    primaryCtaHref = "#",
    secondaryCtaLabel = "Book a demo",
    secondaryCtaHref = "#",
    socialLinks = DEFAULT_SOCIAL,
    headerActions,
    signInLabel = "Sign in",
    signInHref = "/auth",
    className,
}: Hero2Props) {
    const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
    const [hoveredLink, setHoveredLink] = useState<string | null>(null);
    const [activeLink, setActiveLink] = useState<string | null>(
        navLinks.find((link) => link.active)?.label || navLinks[0]?.label || null
    );

    const itemVariants: Variants = {
        hidden: { opacity: 0, y: 15 },
        visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: "easeOut" } },
    };

    const containerVariants: Variants = {
        hidden: { opacity: 0 },
        visible: { opacity: 1, transition: { staggerChildren: 0.1, delayChildren: 0.1 } },
    };

    return (
        <section
            className={cn(
                "relative w-full min-h-screen flex flex-col justify-between overflow-hidden bg-unisafe-smoke-white selection:bg-emerald-100 selection:text-emerald-900",
                className
            )}
        >
            {/* Background Image */}
            <div className="absolute inset-0 z-0 bg-gradient-to-br from-unisafe-dark-midnight-blue/5 to-unisafe-teal/10">
            </div>

            {/* Header / Navbar */}
            <div className="w-full max-w-[1440px] mx-auto relative z-50">
                <header className="flex items-center justify-between px-6 md:px-10 lg:px-16 xl:px-24 py-6 md:py-8">
                    {/* Brand Logo */}
                    <a href="/" className="flex items-center gap-1 group">
                        {typeof brand === "string" ? (
                            <span className="relative text-unisafe-dark-midnight-blue font-bold text-xl tracking-tight select-none">
                                {brand}
                                <span className="absolute top-1 -right-1.5 w-1.5 h-1.5 rounded-full bg-unisafe-teal"></span>
                            </span>
                        ) : (
                            brand
                        )}
                    </a>

                    {/* Desktop Navigation */}
                    <nav className="hidden md:block">
                        <ul className="flex items-center gap-10 lg:gap-14" onMouseLeave={() => setHoveredLink(null)}>
                            {navLinks.map((link) => (
                                <li
                                    key={link.label}
                                    className="relative py-2 flex flex-col items-center group"
                                    onMouseEnter={() => setHoveredLink(link.label)}
                                >
                                    <a
                                        href={link.href}
                                        onClick={(e) => {
                                            if (link.href === "#") e.preventDefault();
                                            setActiveLink(link.label);
                                        }}
                                        className={cn(
                                            "text-sm font-medium transition-colors flex items-center gap-1.5",
                                            (hoveredLink === link.label || (!hoveredLink && activeLink === link.label)) ? "text-unisafe-dark-midnight-blue font-semibold" : "text-unisafe-midnight-blue/70 hover:text-unisafe-dark-midnight-blue"
                                        )}
                                    >
                                        {link.label}
                                        {link.hasDropdown && (
                                            <ChevronDown className="w-3.5 h-3.5 opacity-50 stroke-[2.5] transition-transform duration-200 group-hover:rotate-180" />
                                        )}
                                    </a>
                                    {link.hasDropdown && link.dropdownItems && (
                                        <div className="absolute top-full left-1/2 -translate-x-1/2 pt-4 opacity-0 pointer-events-none group-hover:opacity-100 group-hover:pointer-events-auto transition-all duration-200 z-50">
                                            <div className="bg-white rounded-xl shadow-lg border border-slate-100 p-2 min-w-[180px] flex flex-col gap-1">
                                                {link.dropdownItems.map((item) => (
                                                    <a key={item.label} href={item.href} className="text-sm font-medium text-unisafe-midnight-blue hover:text-unisafe-dark-midnight-blue hover:bg-unisafe-smoke-white px-4 py-2.5 rounded-lg transition-colors whitespace-nowrap text-center">
                                                        {item.label}
                                                    </a>
                                                ))}
                                            </div>
                                        </div>
                                    )}
                                    {/* Active/Hover Indicator Dot */}
                                    {(hoveredLink === link.label || (!hoveredLink && activeLink === link.label)) && (
                                        <motion.span
                                            layoutId="activeDot"
                                            className="absolute -bottom-1.5 w-1 h-1 rounded-full bg-unisafe-teal"
                                            transition={{ type: "spring", stiffness: 400, damping: 30 }}
                                        />
                                    )}
                                </li>
                            ))}
                        </ul>
                    </nav>

                    {/* Desktop Actions */}
                    <div className="hidden md:flex items-center gap-4">
                        {headerActions || (
                            <a href={signInHref}>
                                <Button variant="outline" className="rounded-full px-7 h-10 text-sm font-medium bg-white/60 backdrop-blur-md shadow-[0_0_0_1px_rgba(0,0,0,0.06),inset_0_1px_1px_rgba(255,255,255,0.8),0_1px_2px_rgba(0,0,0,0.04),0_2px_4px_rgba(0,0,0,0.02)] hover:text-black hover:bg-white/80 transition-all text-unisafe-dark-midnight-blue border-0 cursor-pointer">
                                    {signInLabel}
                                </Button>
                            </a>
                        )}
                    </div>

                    {/* Mobile Menu Toggle */}
                    <button
                        onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                        className="md:hidden z-50 p-2 cursor-pointer"
                        aria-label="Toggle mobile menu"
                    >
                        <div className="w-5 flex flex-col gap-1.5">
                            <span className={cn("h-0.5 bg-unisafe-dark-midnight-blue transition-transform", isMobileMenuOpen ? "rotate-45 translate-y-2" : "")} />
                            <span className={cn("h-0.5 bg-unisafe-dark-midnight-blue transition-opacity", isMobileMenuOpen ? "opacity-0" : "")} />
                            <span className={cn("h-0.5 bg-unisafe-dark-midnight-blue transition-transform", isMobileMenuOpen ? "-rotate-45 -translate-y-2" : "")} />
                        </div>
                    </button>
                </header>
            </div>

            {/* Mobile Navigation Drawer */}
            <AnimatePresence>
                {isMobileMenuOpen && (
                    <motion.div
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -20 }}
                        className="fixed inset-0 bg-white/95 backdrop-blur-xl z-40 flex flex-col pt-24 px-6 pb-6 h-screen"
                    >
                        <nav className="flex flex-col gap-6">
                            {navLinks.map((link) => (
                                <a
                                    key={link.label}
                                    href={link.href}
                                    onClick={(e) => {
                                        if (link.href === "#") e.preventDefault();
                                        setActiveLink(link.label);
                                        setIsMobileMenuOpen(false);
                                    }}
                                    className={cn(
                                        "text-2xl font-semibold flex items-center gap-2",
                                        activeLink === link.label ? "text-unisafe-dark-midnight-blue" : "text-unisafe-midnight-blue/70"
                                    )}
                                >
                                    {link.label}
                                </a>
                            ))}
                        </nav>
                        <div className="mt-auto">
                            <a href={signInHref} onClick={() => setIsMobileMenuOpen(false)}>
                                <Button className="w-full rounded-full bg-unisafe-teal hover:opacity-90 text-white h-12 text-base cursor-pointer shadow-md">
                                    {signInLabel}
                                </Button>
                            </a>
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Main Content Area */}
            <motion.div
                variants={containerVariants}
                initial="hidden"
                animate="visible"
                className="relative z-10 flex-1 flex flex-col justify-center w-full max-w-[1440px] mx-auto px-6 md:px-10 lg:px-16 xl:px-24 py-12 md:py-20"
            >
                <div className="max-w-2xl lg:max-w-3xl">
                    <motion.h1
                        variants={itemVariants}
                        className="text-5xl md:text-6xl lg:text-7xl font-medium tracking-tight text-unisafe-dark-midnight-blue leading-[1.08]"
                    >
                        {headline}
                    </motion.h1>

                    <motion.p
                        variants={itemVariants}
                        className="mt-5 text-base md:text-lg text-unisafe-midnight-blue leading-relaxed max-w-2xl whitespace-pre-line"
                    >
                        {description}
                    </motion.p>

                    <motion.div variants={itemVariants} className="mt-8 flex flex-col sm:flex-row items-stretch sm:items-center gap-4">
                        <a href={primaryCtaHref}>
                            <Button className="rounded-full px-8 bg-unisafe-teal hover:brightness-105 text-white h-12 text-sm md:text-base font-medium shadow-[0_0_0_1px_rgba(0,0,0,0.05),inset_0_1px_1px_rgba(255,255,255,0.3),0_4px_16px_rgba(0,0,0,0.1)] border-0 transition-all group cursor-pointer w-full sm:w-auto">
                                {primaryCtaLabel}
                                <ArrowRight className="w-4 h-4 ml-1.5 transition-transform group-hover:translate-x-1" />
                            </Button>
                        </a>

                        <a href={secondaryCtaHref}>
                            <Button variant="secondary" className="rounded-full px-8 bg-[#eaeff1]/80 hover:bg-[#eaeff1] backdrop-blur-sm shadow-[0_0_0_1px_rgba(0,0,0,0.04),inset_0_1px_1px_rgba(255,255,255,0.9),0_2px_4px_rgba(0,0,0,0.02)] text-unisafe-dark-midnight-blue h-12 text-sm md:text-base font-medium border-0 transition-all cursor-pointer w-full sm:w-auto">
                                {secondaryCtaLabel}
                                <Play className="w-3.5 h-3.5 ml-2 fill-unisafe-dark-midnight-blue" />
                            </Button>
                        </a>
                    </motion.div>
                </div>
            </motion.div>

            {/* Bottom Section */}
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.5, duration: 0.8 }}
                className="relative z-10 flex flex-col md:flex-row items-center justify-between w-full max-w-[1440px] mx-auto px-6 md:px-10 lg:px-16 xl:px-24 pb-8 md:pb-12 gap-y-8 gap-x-6"
            >
                {/* Social Links */}
                <div className="flex items-center gap-8 lg:gap-14 w-full md:w-auto justify-center md:justify-start">
                    {socialLinks.map((social) => (
                        <a
                            key={social.label}
                            href={social.href}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-unisafe-midnight-blue/70 hover:text-unisafe-dark-midnight-blue text-sm md:text-base transition-colors"
                        >
                            {social.label}
                        </a>
                    ))}
                </div>

                {/* Scroll Indicator */}
                <div className="flex items-center gap-2 text-unisafe-midnight-blue/70 text-sm md:text-base cursor-pointer group w-full md:w-auto justify-start md:justify-end">
                    <span>Scroll to Discover</span>
                    <motion.span
                        animate={{ y: [0, 4, 0] }}
                        transition={{ repeat: Infinity, duration: 2, ease: "easeInOut" }}
                    >
                        <ArrowDown className="w-4 h-4 transition-transform group-hover:translate-y-1" strokeWidth={1.5} />
                    </motion.span>
                </div>
            </motion.div>
        </section>
    );
}

export default Hero2;
