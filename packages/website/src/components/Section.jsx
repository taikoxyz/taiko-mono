import React from 'react'
import Container from '@mui/material/Container'

function Section({ children, outersx, innersx }) {
  return (
    <Container disableGutters maxWidth={false} sx={{ ...outersx }}>
      <Container disableGutters maxWidth='lg' sx={{ ...innersx }}>
        {children}
      </Container>
    </Container>
  )
}

export default Section
