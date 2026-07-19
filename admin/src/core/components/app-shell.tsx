import {
  AppBar,
  Box,
  Button,
  Drawer,
  List,
  ListItemButton,
  ListItemText,
  Toolbar,
  Typography,
} from '@mui/material';
import type { ReactElement } from 'react';
import { Outlet, useLocation, useNavigate } from 'react-router-dom';

import { ROUTES } from '@/core/router/routes';
import { useSession } from '@/features/auth/session/use-session';

// Fixed drawer width — a structural layout dimension (the MUI-idiomatic
// constant), not a theme spacing token.
const DRAWER_WIDTH = 240;

const SECTIONS = [
  { label: 'Dashboard', path: ROUTES.dashboard },
  { label: 'Brands', path: ROUTES.brands },
  { label: 'Categories', path: ROUTES.categories },
  { label: 'Products', path: ROUTES.products },
  { label: 'Coupons', path: ROUTES.coupons },
  { label: 'Orders', path: ROUTES.orders },
] as const;

/**
 * The single persistent application chrome — the React analog of a Flutter
 * `ShellRoute` shell (react-guidelines §Component Rules; sprint-10-plan Task 03).
 *
 * It hosts the top `AppBar` (title + sign-out) and a permanent `Drawer` with the
 * Dashboard / Brands / Categories / Products / Coupons / Orders navigation (Dashboard first,
 * sprint-13-plan Task 03), and renders the active section in the content area via the router
 * `Outlet`. Sign-out clears the session; the guard then
 * redirects to login off the session-state change (mirroring the Flutter
 * state-driven redirect). Features plug their pages into the outlet, never the
 * reverse.
 */
export function AppShell(): ReactElement {
  const { logout } = useSession();
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar position="fixed" sx={{ zIndex: (theme) => theme.zIndex.drawer + 1 }}>
        <Toolbar>
          <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
            FootVerse Admin
          </Typography>
          <Button
            color="inherit"
            onClick={() => {
              void logout();
            }}
          >
            Sign out
          </Button>
        </Toolbar>
      </AppBar>
      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': { width: DRAWER_WIDTH, boxSizing: 'border-box' },
        }}
      >
        <Toolbar />
        <List>
          {SECTIONS.map((section) => {
            // The shell's index route (`ROUTES.root`) also renders the
            // dashboard (sprint-13-plan Task 03), so the Dashboard entry is
            // selected on either path — the only section reachable by two
            // routes.
            const isSelected =
              section.path === ROUTES.dashboard
                ? location.pathname === ROUTES.root || location.pathname.startsWith(section.path)
                : location.pathname.startsWith(section.path);
            return (
              <ListItemButton
                key={section.path}
                selected={isSelected}
                onClick={() => navigate(section.path)}
              >
                <ListItemText primary={section.label} />
              </ListItemButton>
            );
          })}
        </List>
      </Drawer>
      <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
        <Toolbar />
        <Outlet />
      </Box>
    </Box>
  );
}
