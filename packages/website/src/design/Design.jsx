import React, { useEffect, useState } from 'react'
import { useTheme } from '@mui/material/styles'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import Typography from '@mui/material/Typography'
import FavoriteIcon from '@mui/icons-material/Favorite'
import { Header } from '../components/Header'
import ReactMarkdown from 'react-markdown'
import { grey } from '@mui/material/colors'
import RemarkMathPlugin from 'remark-math'
import RehypeKatex from 'rehype-katex'
import 'katex/dist/katex.min.css'
import './Design.css'
import Section from '../components/Section'
import Footer from '../components/Footer'

function Design() {
  const theme = useTheme()
  let [content, setContent] = useState({ md: '' })

  useEffect(() => {
    fetch('/b/DESIGN.md')
      .then((res) => res.text())
      .then((md) => {
        setContent({ md })
      })
  }, [])

  return (
    <>
      <Section>
        <Header activePage='design' />
      </Section>

      <Section>
        <Box sx={{ pt: 16, pb: 4, px: { md: 8, sm: 4, xs: 2 } }}>
          <FavoriteIcon sx={{ color: 'primary.main' }} />
          <FavoriteIcon sx={{ color: 'primary.main' }} />
          <FavoriteIcon sx={{ color: 'primary.main' }} />

          <Typography gutterBottom sx={{ color: 'text.secondary', fontWeight: 'bold' }}>
            TAIKO won&apos;t even be possible without the many great works from the Ethereum
            Foundation, ZCash, Scroll, Loopring, etc.Thank you all! (Sorry if we missed your or your
            team&apos;s name in the list. Please kindly let us know.)
          </Typography>
        </Box>
      </Section>

      <Section>
        <Paper
          elevation={5}
          className='markdown'
          sx={{
            minHeight: '100vh',
            py: 12,
            px: { md: 16, sm: 4, xs: 2 },
            userSelect: 'none',
            background: theme.mode === 'dark' ? grey[800] : 'white',
            color: 'text.primary',
          }}
        >
          <Typography
            variant='h2'
            component='h2'
            gutterBottom
            sx={{ pb: 4, fontFamily: 'Major Mono Display' }}
          >
            Design
          </Typography>

          <ReactMarkdown
            remarkPlugins={[RemarkMathPlugin]}
            rehypePlugins={[RehypeKatex]}
            style={{}}
          >
            {content.md}
          </ReactMarkdown>
        </Paper>
      </Section>

      <Section>
        <Footer />
      </Section>
    </>
  )
}

export default Design
