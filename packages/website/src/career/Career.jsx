import React from 'react'
import { useTheme } from '@mui/material/styles'
import Link from '@mui/material/Link'
import Button from '@mui/material/Button'
import Box from '@mui/material/Box'
import Grid from '@mui/material/Grid'
import Typography from '@mui/material/Typography'
import { Header } from '../components/Header'
import Footer from '../components/Footer'
import { cyan, grey, pink } from '@mui/material/colors'
import Section from '../components/Section'

const darkBgColor = 'rgb(9,9,9)'

const jobs = [
  {
    title: 'cryptogrAphy  reseArcher',
    desc: ['Drive the cutting-edge research and application of cryptography in Applied-zkEVM.'],
    qualifications: [
      'Strong background in cryptography and math, and deep understanding of ZKP protocols.',
      'A strong inclination to stay abreast of the field, and help advance it.',
      'Experience in Rust, C++, or similar programming language.',
      'Ability to perform, synthesize, distill, and convey cryptographic research.',
      'Understanding of Ethereum development is preferred.',
    ],
  },

  {
    title: 'senior full stAck engineer',
    desc: [
      'Design and develop high-quality frontend applications and backend services that interface with our zkEVM.',
    ],
    qualifications: [
      '6+ years experience in software engineering.',
      'Strong experience with TypeScript or JavaScript and modern frameworks such as React.',
      'Significant experience writing solidity smart contracts (including assembly code) and deploying to production.',
      'Understanding of Ethereum is preferred, as is familiarity with ethers/web3 JS libraries, and hardhat/truffle.',
    ],
  },
]
function Job({ job }) {
  const theme = useTheme()
  return (
    <Grid item xs={12} sm={12} md={6}>
      <Box sx={{ p: 4, color: theme.palette.text.secondary, fontWeight: 600 }}>
        <Typography
          variant='h5'
          sx={{
            pb: 4,
            color: theme.palette.primary.main,
            fontWeight: 800,
            fontFamily: 'Major Mono Display',
          }}
        >
          {job.title}
        </Typography>

        <Typography variant='h7' sx={{ color: theme.palette.text.primary }}>
          About this role
        </Typography>
        <ul>
          {job.desc.map((q, i) => (
            <li key={i}>{q}</li>
          ))}
        </ul>

        <Typography variant='h7' sx={{ color: theme.palette.text.primary }}>
          About you
        </Typography>

        <ul>
          {job.qualifications.map((q, i) => (
            <li key={i}>{q}</li>
          ))}
        </ul>
      </Box>
    </Grid>
  )
}

function Openings({ theme }) {
  return (
    <Grid container spacing={4}>
      {jobs.map((job, i) => (
        <Job key={i} job={job} />
      ))}
    </Grid>
  )
}

function Hero({ theme }) {
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
      <Typography
        sx={{ fontSize: { xs: 40, md: 60 }, fontWeight: 800, px: 12, pt: 4, color: 'white' }}
      >
        We have a <span style={{ color: cyan[500] }}>remote friendly</span> job for you!
      </Typography>
    </Box>
  )
}

function Career() {
  const theme = useTheme()
  const bannerBgColor = theme.mode == 'dark' ? darkBgColor : 'white'

  return (
    <>
      <Section outersx={{ background: bannerBgColor }}>
        <Header activePage='career' bgColor={bannerBgColor} />
      </Section>

      <Section
        outersx={{
          py: 16,
          backgroundColor: grey[900],
          backgroundImage: 'url(https://htmlrev.com/preview/vera/images/header-background.jpg)',
        }}
        innersx={{
          py: 8,
          backgroundImage:
            'radial-gradient(' + pink[400] + ' 0.7px, ' + ' transparent ' + ' 0.7px)',
          backgroundSize: '14px 14px',
        }}
      >
        <Hero theme={theme} />
      </Section>

      <Section
        outersx={{
          pt: 16,
        }}
      >
        <Openings theme={theme} />
        <Box
          sx={{
            px: 8,
            pt: 4,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'right',
            justifyContent: 'center',
            border: '0px solid blue',
            minHeight: '320px',
          }}
        >
          {' '}
          <Button
            variant='outlined'
            color='primary'
            onClick={(e) => {
              window.open('mailto:jobs@taiko.xyz', '_blank')
            }}
            sx={{
              width: '100%',
              fontSize: '18px',
              fontWeight: 'bold',
            }}
          >
            Apply Now
          </Button>
        </Box>
      </Section>

      <Section outersx={{ background: bannerBgColor }}>
        <Footer />
      </Section>
    </>
  )
}

export default Career
