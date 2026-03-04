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
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
    },
  },
  plugins: [],
};
