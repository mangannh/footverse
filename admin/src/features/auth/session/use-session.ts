import { useContext } from 'react';

import { SessionContext, type SessionContextValue } from './session-context';

/**
 * Reads the session state and actions — the single accessor of the app-root
 * session (react-guidelines §State Management). Throws when used outside a
 * [SessionProvider].
 */
export function useSession(): SessionContextValue {
  const context = useContext(SessionContext);
  if (context === null) {
    throw new Error('useSession must be used within a SessionProvider');
  }
  return context;
}
