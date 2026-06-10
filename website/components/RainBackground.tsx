'use client'

import { useEffect, useRef } from 'react'

export default function RainBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let width = window.innerWidth
    let height = window.innerHeight
    canvas.width = width
    canvas.height = height

    const handleResize = () => {
      width = window.innerWidth
      height = window.innerHeight
      canvas.width = width
      canvas.height = height
    }

    window.addEventListener('resize', handleResize)

    // Configuration
    const lineCount = 120; // Increased count for more rain
    const angle = Math.PI / 8; // Slanted angle
    
    // Brighter colors for dark mode
    const darkColors = [
      'rgba(255, 255, 255, 0.4)', 
      'rgba(255, 235, 59, 0.35)', 
      'rgba(33, 150, 243, 0.4)'
    ]
    
    // Tracelet themed colors for light mode
    const lightColors = [
      'rgba(0, 0, 0, 0.15)', 
      'rgba(15, 157, 88, 0.25)', // Tracelet Green
      'rgba(33, 150, 243, 0.25)'
    ]
    
    interface Drop {
      x: number
      y: number
      length: number
      speed: number
      colorIndex: number
    }

    const drops: Drop[] = []
    for (let i = 0; i < lineCount; i++) {
      drops.push({
        x: Math.random() * width * 1.5 - width * 0.5,
        y: Math.random() * height,
        length: Math.random() * 20 + 10,
        speed: Math.random() * 2 + 1,
        colorIndex: Math.floor(Math.random() * 3) // 0, 1, or 2
      })
    }

    let animationFrameId: number

    const render = () => {
      ctx.clearRect(0, 0, width, height)
      
      const isDark = document.documentElement.classList.contains('dark')
      const activeColors = isDark ? darkColors : lightColors
      
      ctx.lineWidth = 1 // Keeping thickness exactly the same
      
      for (let i = 0; i < drops.length; i++) {
        const drop = drops[i]
        
        ctx.beginPath()
        ctx.strokeStyle = activeColors[drop.colorIndex]
        ctx.moveTo(drop.x, drop.y)
        
        const endX = drop.x + Math.sin(angle) * drop.length
        const endY = drop.y + Math.cos(angle) * drop.length
        
        ctx.lineTo(endX, endY)
        ctx.stroke()

        // Move
        drop.x += Math.sin(angle) * drop.speed
        drop.y += Math.cos(angle) * drop.speed

        // Reset if off screen
        if (drop.y > height || drop.x > width) {
          drop.x = Math.random() * width * 1.5 - width * 0.5
          drop.y = -drop.length
          // Randomize color index on reset for dynamic color shifting feel
          drop.colorIndex = Math.floor(Math.random() * 3)
        }
      }

      animationFrameId = requestAnimationFrame(render)
    }

    render()

    return () => {
      window.removeEventListener('resize', handleResize)
      cancelAnimationFrame(animationFrameId)
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100vh',
        pointerEvents: 'none',
        zIndex: -1,
        opacity: 0.8,
      }}
    />
  )
}
