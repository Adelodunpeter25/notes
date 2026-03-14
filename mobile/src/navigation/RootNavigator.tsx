import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";
import { ActivityIndicator, View } from "react-native";
import { useEffect, useState } from "react";

import type { AppStackParamList, AuthStackParamList } from "./types";
import { LoginScreen, SignupScreen } from "@/screens/auth";
import { DashboardScreen, FolderDetailsScreen } from "@/screens/dashboard";
import { NoteEditorScreen } from "@/screens/editor";
import { SearchScreen } from "@/screens/search";
import { useAuthStore } from "@/stores/authStore";
import { colors } from "@/theme/colors";
import { navigationTheme } from "@/theme/navigationTheme";
import { apiClient } from "@/api/apiClient";
import type { AuthUser } from "@shared/auth";
import { authStorage } from "@/utils/authStorage";
import { useSync } from "@/hooks";

const AuthStack = createStackNavigator<AuthStackParamList>();
const AppStack = createStackNavigator<AppStackParamList>();

function AuthNavigator() {
  return (
    <AuthStack.Navigator
      initialRouteName="Login"
      screenOptions={{
        headerShown: false,
        animation: "none",
        cardStyle: { backgroundColor: colors.background },
      }}
    >
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Signup" component={SignupScreen} />
    </AuthStack.Navigator>
  );
}

function MainNavigator() {
  return (
    <AppStack.Navigator
      screenOptions={{
        headerShown: false,
        animation: "none",
        cardStyle: { backgroundColor: colors.background },
      }}
    >
      <AppStack.Screen name="Dashboard" component={DashboardScreen} />
      <AppStack.Screen name="FolderDetails" component={FolderDetailsScreen} />
      <AppStack.Screen name="Editor" component={NoteEditorScreen} />
      <AppStack.Screen name="Search" component={SearchScreen} />
    </AppStack.Navigator>
  );
}

export function RootNavigator() {
  const token = useAuthStore((state) => state.token);
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const setAuth = useAuthStore((state) => state.setAuth);
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const [isBootstrappingAuth, setIsBootstrappingAuth] = useState(true);
  const [hasSession, setHasSession] = useState(false);
  useSync();

  useEffect(() => {
    let active = true;

    async function bootstrapAuth() {
      try {
        const existingToken = await authStorage.getToken();

        if (existingToken) {
          if (active) {
            // Eagerly assume logged in and dismiss the splash loader so the app opens instantly.
            setHasSession(true);
            setIsBootstrappingAuth(false);
          }

          // Then verify token in background. If it fails, they will eventually get logged out.
          try {
            const response = await apiClient.instance.get<AuthUser>("/auth/me", {
              headers: { Authorization: `Bearer ${existingToken}` },
              timeout: 5000,
            });

            if (active) {
              setAuth({ token: existingToken, user: response.data });
            }
          } catch (error: any) {
            if (!active) {
              return;
            }

            if (error?.status === 401 || error?.response?.status === 401) {
              clearAuth();
              setHasSession(false);
            }
          }
        } else if (active) {
          clearAuth();
          setHasSession(false);
          setIsBootstrappingAuth(false);
        }
      } catch (err) {
        console.error("Bootstrap error:", err);
        if (active) {
          setHasSession(false);
          setIsBootstrappingAuth(false);
        }
      }
    }

    void bootstrapAuth();

    return () => {
      active = false;
    };
  }, [clearAuth, setAuth]);

  if (isBootstrappingAuth) {
    return (
      <View className="flex-1 items-center justify-center bg-background">
        <ActivityIndicator color="#eab308" />
      </View>
    );
  }

  // Source of truth: Do we have a token? If yes, show the app.
  // /auth/me will kick them out later if the token is invalid.
  const isUserAuthenticated = isAuthenticated || hasSession;

  return (
    <NavigationContainer theme={navigationTheme}>
      {isUserAuthenticated ? <MainNavigator /> : <AuthNavigator />}
    </NavigationContainer>
  );
}
