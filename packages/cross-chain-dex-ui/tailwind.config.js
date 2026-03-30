/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'surge-primary': '#10b981',      // Emerald green
        'surge-secondary': '#06b6d4',    // Cyan blue
        'surge-accent': '#22d3ee',       // Light cyan
        'surge-dark': '#06090e',         // Near-black base
        'surge-card': '#0b1219',         // Dark charcoal card
        'surge-card-hover': '#0f1a25',   // Slightly lifted hover
        'surge-border': '#182030',       // Subtle dark border
        'surge-text': '#e2e8f0',         // Light gray text
        'surge-muted': '#64748b',        // Muted text
      },
      backgroundImage: {
        'surge-gradient': 'linear-gradient(135deg, #0a1628 0%, #0f2847 50%, #0a1628 100%)',
        'surge-glow': 'radial-gradient(ellipse at top, rgba(16, 185, 129, 0.15) 0%, transparent 50%)',
      },
    },
  },
  plugins: [],
}
