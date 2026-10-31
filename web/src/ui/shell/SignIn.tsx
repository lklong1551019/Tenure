import type { SignInFailureText } from './messages'
import './shell.css'

/** The first screen: what this is, and one button. */
export function SignIn(props: {
  state: 'notConfigured' | 'loading' | 'signedOut'
  failure?: SignInFailureText
  namespace: string
  onSignIn: () => void
}) {
  return (
    <main className="sign-in">
      <div className="sign-in-card card">
        <div className="app-mark" aria-hidden="true">
          T
        </div>
        <h1>Tenure</h1>
        <p>Your boards and tasks</p>
        {props.namespace === 'demo' && (
          <p className="sign-in-note">Demo: sample data, no Google account.</p>
        )}
        {props.namespace === 'dev' && (
          <p className="sign-in-note">Test data: the Mac app's Debug file.</p>
        )}
        {props.state === 'notConfigured' ? (
          <p className="sign-in-note">
            Sync isn't set up in this build: it has no Google client id.
          </p>
        ) : (
          <button
            type="button"
            className="button button-primary sign-in-button"
            disabled={props.state === 'loading'}
            onClick={props.onSignIn}
          >
            {props.state === 'loading' ? 'Loading...' : 'Sign in with Google'}
          </button>
        )}
        {props.failure && <p className="sign-in-error">{props.failure}</p>}
        <p className="sign-in-fine">
          Asks only for the files Tenure created. <a href="../privacy.html">Privacy</a>
        </p>
      </div>
    </main>
  )
}
