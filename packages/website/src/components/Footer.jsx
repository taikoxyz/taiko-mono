import React from 'react'

import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import Avatar from '@mui/material/Avatar'
import { grey } from '@mui/material/colors'
import { useTheme } from '@mui/material/styles'
import TwitterIcon from '@mui/icons-material/Twitter'
import GitHubIcon from '@mui/icons-material/GitHub'
import Forum from '@mui/icons-material/Forum'
import SendIcon from '@mui/icons-material/Send'

const SocialLink = ({ url, children }) => {
  const theme = useTheme()

  return (
    <a href={url}>
      <Box sx={{ p: { md: 2, sm: 2, xs: 2 }, display: 'inline-block' }}>
        <Avatar
          sx={{
            color: theme.mode === 'dark' ? grey[900] : 'white',
            background: theme.mode === 'dark' ? 'white' : grey[900],
            transition: 'background 0.3s ',
            '&:hover': {
              background: theme.palette.primary.main,
            },
          }}
        >
          {children}
        </Avatar>
      </Box>
    </a>
  )
}

const Footer = () => {
  const theme = useTheme()

  return (
    <>
      <Box
        sx={{
          pb: 2,
          pt: 16,
          display: 'flex',
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <SocialLink url='https://twitter.com/taikoxyz'>
          <TwitterIcon size='lg' />
        </SocialLink>
        <SocialLink url='https://github.com/taikochain'>
          <GitHubIcon size='lg' />
        </SocialLink>
        <SocialLink url='https://discord.gg/tnSra3aFfg'>
          <Forum size='lg' />
        </SocialLink>
        <SocialLink url='mailto:info@taiko.xyz'>
          <SendIcon size='lg' />
        </SocialLink>
      </Box>
      <Box
        sx={{
          py: 1,
          display: 'flex',
          flexDirection: 'row',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Typography variant='h8' sx={{ fontWeight: 500, color: theme.palette.text.secondary }}>
          ©Taiko Labs, 2022
        </Typography>
      </Box>
    </>
  )
}

export default Footer
