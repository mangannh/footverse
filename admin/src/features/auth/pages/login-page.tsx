import {
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Container,
  Snackbar,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useRef, useState, type FormEvent, type ReactElement } from 'react';

import { AppError } from '@/core/error/app-error';

import { useSession } from '../session/use-session';
import { authValidators } from '../validators/auth-validators';

const UNEXPECTED_MESSAGE = 'An unexpected error occurred';

/**
 * The admin sign-in screen — the React analog of the Flutter `LoginScreen`.
 *
 * It collects credentials, pre-validates them against the frozen constraints,
 * and drives [useSession].`login`. On success the router redirect navigates away
 * (Task 03, off the session state); a login failure or the non-administrator
 * rejection renders the enveloped / client message in a `Snackbar`. The login is
 * single-flight (the session guards it and the button disables while it runs).
 */
export function LoginPage(): ReactElement {
  const { login, isSubmitting } = useSession();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [emailError, setEmailError] = useState<string>();
  const [passwordError, setPasswordError] = useState<string>();
  const [errorMessage, setErrorMessage] = useState<string>();
  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    const nextEmailError = authValidators.email(email);
    const nextPasswordError = authValidators.requiredPassword(password);
    setEmailError(nextEmailError);
    setPasswordError(nextPasswordError);
    if (nextEmailError !== undefined) {
      emailRef.current?.focus();
      return;
    }
    if (nextPasswordError !== undefined) {
      passwordRef.current?.focus();
      return;
    }
    try {
      await login({ email: email.trim(), password });
    } catch (error) {
      setErrorMessage(error instanceof AppError ? error.message : UNEXPECTED_MESSAGE);
    }
  }

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center' }}>
      <Container maxWidth="xs">
        <Card>
          <CardContent>
            <form
              noValidate
              onSubmit={(event) => {
                void handleSubmit(event);
              }}
            >
              <Stack spacing={3}>
                <Typography variant="h5" component="h1">
                  FootVerse Admin
                </Typography>
                <TextField
                  label="Email"
                  type="email"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  error={emailError !== undefined}
                  helperText={emailError}
                  inputRef={emailRef}
                  disabled={isSubmitting}
                  autoComplete="email"
                  fullWidth
                />
                <TextField
                  label="Password"
                  type="password"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  error={passwordError !== undefined}
                  helperText={passwordError}
                  inputRef={passwordRef}
                  disabled={isSubmitting}
                  autoComplete="current-password"
                  fullWidth
                />
                <Button
                  type="submit"
                  variant="contained"
                  disabled={isSubmitting}
                  startIcon={
                    isSubmitting ? <CircularProgress size={20} color="inherit" /> : undefined
                  }
                >
                  Sign in
                </Button>
              </Stack>
            </form>
          </CardContent>
        </Card>
      </Container>
      <Snackbar
        open={errorMessage !== undefined}
        autoHideDuration={6000}
        onClose={() => setErrorMessage(undefined)}
        message={errorMessage}
      />
    </Box>
  );
}
