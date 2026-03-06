/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#EBF5FF', 100: '#D6EBFF', 200: '#ADD6FF', 300: '#70B8FF',
          400: '#3399FF', 500: '#0A74DA', 600: '#1E3A5F', 700: '#162D4A',
          800: '#0F1F35', 900: '#081220',
        },
        accent: { 400: '#22D3EE', 500: '#06B6D4', 600: '#0891B2' },
        surface: {
          base: 'rgb(var(--surface-base) / <alpha-value>)',
          elevated: 'rgb(var(--surface-elevated) / <alpha-value>)',
          glass: 'rgb(var(--surface-glass) / <alpha-value>)',
        },
        text: {
          primary: 'rgb(var(--text-primary) / <alpha-value>)',
          muted: 'rgb(var(--text-muted) / <alpha-value>)',
        },
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
      borderRadius: {
        xl: '1rem',
        '2xl': '1.25rem',
      },
      boxShadow: {
        glass: '0 20px 50px rgba(8, 18, 32, 0.25)',
        soft: '0 10px 25px rgba(8, 18, 32, 0.08)',
      },
      backdropBlur: {
        xs: '2px',
      },
    },
  },
  plugins: [],
};
