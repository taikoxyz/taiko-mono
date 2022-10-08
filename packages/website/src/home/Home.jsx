import React from 'react'
import { useTheme } from '@mui/material/styles'
import Box from '@mui/material/Box'
import Button from '@mui/material/Button'
import Grid from '@mui/material/Grid'
import Typography from '@mui/material/Typography'
import { Header } from '../components/Header'
import Footer from '../components/Footer'
import { Link } from 'react-router-dom'
import './Home.css'
import { grey } from '@mui/material/colors'
import Section from '../components/Section'

function Hero({ theme }) {
  return (
    <Grid container spacing={0}>
      <Grid item xs={12} sm={12} md={6}>
        <Box
          sx={{
            p: 4,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'right',
            justifyContent: 'center',
            border: '0px solid blue',
            height: '100%',
            minHeight: '320px',
          }}
        >
          <Typography variant='h3' sx={{ fontWeight: 800, color: theme.palette.text.primary }}>
            <div>
              A <span style={{ color: theme.palette.primary.main }}>decentralized</span>
            </div>

            <div>ZK-Rollup</div>
            <div>
              with EVM <span style={{ color: theme.palette.primary.main }}>compatibility</span>{' '}
              pushed to the limit
            </div>
          </Typography>

          <Typography variant='h6' sx={{ pt: 4, color: theme.palette.text.secondary }}>
            Learn more from our <a href='https://drive.google.com/file/d/1EIJq_XBbb1Y9k6Pe0szUkNoVKILTcO2R/view?usp=sharing'>whitepaper</a>.
          </Typography>
        </Box>
      </Grid>
      <Grid item xs={12} sm={12} md={6}>
        <Box className='spin' sx={{ p: 8, minHeight: { md: '680px', sm: '500px', xs: '420px' } }}>
          <Box className='inside' />
        </Box>
      </Grid>
    </Grid>
  )
}

function Hiring({ theme }) {
  const bannerBgColor = theme.mode === 'dark' ? grey[900] : grey[100]
  const bannerTextColor = theme.palette.text.primary
  return (
    <Box
      sx={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Typography variant='h4' sx={{ fontWeight: 700, pt: 4, color: bannerTextColor }}>
        There is a lot to be done, including this site.
        <br />
        Would you like to <span style={{ color: 'secondary.main' }}>#buidl</span> with us?
      </Typography>

      <Box sx={{ mt: 12 }}>
        <Button
          disableElevation
          variant='outlined'
          href='/career/'
          color='primary'
          sx={{
            background: bannerBgColor,
            fontSize: '18px',
            fontWeight: 'bold',
          }}
        >
          Learn about our opportunities
        </Button>
      </Box>
    </Box>
  )
}
function Home() {
  const theme = useTheme()

  const bannerBgColor = theme.mode === 'dark' ? grey[900] : grey[100]
  return (
    <>
      <Section>
        <Header />
      </Section>

      <Section>
        <Hero theme={theme} />
      </Section>

      <Section
        innersx={{
          py: 16,
          backgroundImage: 'radial-gradient(' + grey[600] + ' 0.7px, ' + bannerBgColor + ' 0.7px)',
          backgroundSize: '14px 14px',
        }}
      >
        <Hiring theme={theme} />
      </Section>

      <Section>
        <Footer />
      </Section>
    </>
  )
}

export default Home
