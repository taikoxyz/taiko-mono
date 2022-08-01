import React from 'react'

import { Link } from 'react-router-dom'
import AppBar from '@mui/material/AppBar'
import Box from '@mui/material/Box'
import Toolbar from '@mui/material/Toolbar'
import IconButton from '@mui/material/IconButton'
import Typography from '@mui/material/Typography'
import Menu from '@mui/material/Menu'
import MenuIcon from '@mui/icons-material/Menu'
import Container from '@mui/material/Container'
import Button from '@mui/material/Button'
import MenuItem from '@mui/material/MenuItem'
import Brightness4Icon from '@mui/icons-material/Brightness4'
import Brightness7Icon from '@mui/icons-material/Brightness7'
import { useTheme } from '@mui/material/styles'

const pages = ['design', 'career']
const settings = ['Profile', 'Account', 'Dashboard', 'Logout']

const ColorModeContext = React.createContext({ toggleColorMode: () => {} })

const Header = ({ activePage, bgColor }) => {
  const [anchorElNav, setAnchorElNav] = React.useState(null)
  const [anchorElUser, setAnchorElUser] = React.useState(null)

  const handleOpenNavMenu = (event) => {
    setAnchorElNav(event.currentTarget)
  }
  const handleOpenUserMenu = (event) => {
    setAnchorElUser(event.currentTarget)
  }

  const handleCloseNavMenu = () => {
    setAnchorElNav(null)
  }

  const handleCloseUserMenu = () => {
    setAnchorElUser(null)
  }

  const colorMode = React.useContext(ColorModeContext)
  const theme = useTheme()

  return (
    <AppBar position='static' elevation={0} sx={{ backgroundColor: bgColor || 'transparent' }}>
      <Container>
        <Toolbar disableGutters style={{ minHeight: 96 }}>
          <Box
            sx={{
              color: 'black',
              height: '36px',
              userSelect: 'none',
              display: { xs: 'none', md: 'flex' },
            }}
          >
            <Typography
              variant='h5'
              noWrap
              href='/'
              component='a'
              sx={{
                color: theme.palette.text.primary,
                fontWeight: 800,
                fontFamily: 'Major Mono Display',
                ml: 6,
                flexGrow: 1,
                letterSpacing: '.3rem',
                textDecoration: 'none',
              }}
            >
              t<span style={{ color: theme.palette.primary.main }}>A</span>iko
            </Typography>
          </Box>

          <Box sx={{ flexGrow: 1, display: { xs: 'flex', md: 'none' } }}>
            <IconButton
              size='large'
              aria-label='account of current user'
              aria-controls='menu-appbar'
              aria-haspopup='true'
              onClick={handleOpenNavMenu}
              sx={{ color: theme.palette.text.primary }}
            >
              <MenuIcon />
            </IconButton>
            <Menu
              id='menu-appbar'
              anchorEl={anchorElNav}
              anchorOrigin={{
                vertical: 'bottom',
                horizontal: 'left',
              }}
              keepMounted
              transformOrigin={{
                vertical: 'top',
                horizontal: 'left',
              }}
              open={Boolean(anchorElNav)}
              onClose={handleCloseNavMenu}
              sx={{
                display: { xs: 'block', md: 'none' },
                '.MuiPaper-root': {
                  backgroundColor: bgColor || theme.palette.background.default,
                },
              }}
            >
              {pages.map((page) => (
                <MenuItem key={page} sx={{ m: 0, p: 0 }}>
                  <Link to={'/' + page} style={{ textDecoration: 'none' }}>
                    <Button
                      key={page}
                      sx={{
                        py: 2,
                        px: 6,

                        color:
                          activePage === page
                            ? theme.palette.primary.main
                            : theme.palette.text.primary,

                        display: 'block',
                        fontWeight: 600,
                      }}
                    >
                      {page}
                    </Button>
                  </Link>
                </MenuItem>
              ))}
            </Menu>
          </Box>
          <Typography
            variant='h5'
            noWrap
            component='a'
            href='/'
            sx={{
              color: theme.palette.text.primary,
              fontWeight: 800,
              fontFamily: 'Major Mono Display',
              ml: 6,
              display: { xs: 'flex', md: 'none' },
              flexGrow: 1,
              letterSpacing: '.3rem',
              textDecoration: 'none',
            }}
          >
            t<span style={{ color: theme.palette.primary.main }}>A</span>iko
          </Typography>

          <Box sx={{ flexGrow: 1 }}></Box>

          <Box sx={{ flexGrow: 0, display: { xs: 'none', md: 'flex' } }}>
            {pages.map((page) => (
              <Link key={page} to={'/' + page} style={{ textDecoration: 'none' }}>
                <Button
                  key={page}
                  style={{ backgroundColor: 'transparent' }}
                  // diabled={activePage === page? "true":"false"}
                  sx={{
                    borderBottom: '2px solid transparent',
                    borderRadius: 0,
                    p: 0,
                    m: 1,
                    color:
                      activePage === page ? theme.palette.primary.main : theme.palette.text.primary,
                    display: 'block',
                    fontWeight: 600,

                    '&.MuiButtonBase-root:hover': {
                      color: theme.palette.primary.main,
                      borderBottomColor: theme.palette.primary.main,
                    },
                  }}
                >
                  {page}
                </Button>
              </Link>
            ))}
          </Box>

          <Box
            sx={{
              alignItems: 'center',
              justifyContent: 'center',
              color: 'text.primary',
            }}
          >
            <IconButton
              sx={{
                ml: 1,

                '&.MuiButtonBase-root:hover': {
                  color: theme.palette.primary.main,
                  borderBottomColor: theme.palette.primary.main,
                },
              }}
              onClick={colorMode.toggleColorMode}
              color='inherit'
            >
              {theme.palette.mode === 'dark' ? <Brightness7Icon /> : <Brightness4Icon />}
            </IconButton>
          </Box>
        </Toolbar>
      </Container>
    </AppBar>
  )
}

export { Header, ColorModeContext }
