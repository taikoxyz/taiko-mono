import React from 'react'
import './App.css'

import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { ThemeProvider, createTheme } from '@mui/material/styles'
import { grey, pink } from '@mui/material/colors'
import { CssBaseline, GlobalStyles } from '@mui/material'
import { ColorModeContext } from './components/Header'
import Home from './home/Home'
import Design from './design/Design'
import Career from './career/Career'

export default function App() {
  const [mode, setMode] = React.useState('light')
  const colorMode = React.useMemo(
    () => ({
      toggleColorMode: () => {
        setMode((prevMode) => (prevMode === 'light' ? 'dark' : 'light'))
      },
    }),
    [],
  )

  const theme = React.useMemo(
    () =>
      createTheme({
        mode,
        palette: {
          ...(mode === 'light'
            ? {
                primary: pink,
                background: {
                  default: '#fff',
                },
                text: {
                  primary: grey[900],
                  secondary: grey[600],
                },
              }
            : {
                primary: pink,
                background: {
                  default: grey[900],
                },
                text: {
                  primary: grey[100],
                  secondary: grey[500],
                },
              }),
        },
        typography: {
          fontFamily: [
            'Poppins',
            '-apple-system',
            'BlinkMacSystemFont',
            '"Segoe UI"',
            'Roboto',
            '"Helvetica Neue"',
            'Arial',
            'sans-serif',
            '"Apple Color Emoji"',
            '"Segoe UI Emoji"',
            '"Segoe UI Symbol"',
          ].join(','),
        },
        custom: {
          ...(mode === 'light'
            ? {
                logoUrl: '/logo-dark.png',
                backgroundDottedColor: grey[400],
                linkColor: pink[600],
                linkHoverColor: pink[400],
              }
            : {
                logoUrl: '/logo-light.png',
                backgroundDottedColor: grey[800],
                linkColor: pink[600],
                linkHoverColor: pink[400],
              }),
        },
      }),
    [mode],
  )

  return (
    <ColorModeContext.Provider value={colorMode}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <GlobalStyles
          styles={{
            a: {
              color: '' + theme.custom.linkColor,
            },
            'a:hover': {
              color: '' + theme.custom.linkHoverColor,
            },
            body: {
              backgroundImage:
                'radial-gradient(' +
                theme.custom.backgroundDottedColor +
                ' 0.7px, ' +
                theme.palette.background.default +
                ' 0.7px)',
              backgroundSize: '14px 14px',
            },
          }}
        />
        <BrowserRouter>
          <Routes>
            <Route path='/' element={<Home />} />
            <Route path='/design' element={<Design />} />
            <Route path='/career' element={<Career />} />
          </Routes>
        </BrowserRouter>
      </ThemeProvider>
    </ColorModeContext.Provider>
  )
}
