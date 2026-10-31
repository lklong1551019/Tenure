// The tokens and base styles first, so every component's own CSS can override them.
import '../ui/theme.css'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import { App } from './App'
import { makeAppModel } from './dependencies'

// A HashRouter (#/b/<board>/t/<task>): GitHub Pages serves index.html only at /Tenure/app/,
// so a deep path would 404 on reload, while a hash never reaches the server.
const model = await makeAppModel()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <HashRouter>
      <App model={model} />
    </HashRouter>
  </StrictMode>,
)
