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
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const setAuth = useAuthStore((state) => state.setAuth);
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const [isBootstrappingAuth, setIsBootstrappingAuth] = useState(true);

  useEffect(() => {
    let active = true;

    // Safety fallback to hide loading screen if bootstrap hangs
    const timeout = setTimeout(() => {
      if (active) {
        setIsBootstrappingAuth(false);
      }
    }, 5000);

    async function bootstrapAuth() {
      try {
        // 1. Wait for AsyncStorage to load into Zustand
        await useAuthStore.persist.rehydrate();

        const token = useAuthStore.getState().token;
        if (!token) {
          if (active) setIsBootstrappingAuth(false);
          return;
        }

        // 2. Validate token with server
        const response = await apiClient.instance.get<AuthUser>("/auth/me", {
          headers: { Authorization: `Bearer ${token}` },
        });

        if (active) {
          setAuth({ token, user: response.data });
        }
      } catch (error: any) {
        // Only clear if server says token is invalid (401)
        if (error?.status === 401) {
          clearAuth();
        }
      } finally {
        if (active) {
          setIsBootstrappingAuth(false);
          clearTimeout(timeout);
        }
      }
    }

    void bootstrapAuth();

    return () => {
      active = false;
      clearTimeout(timeout);
    };
  }, [clearAuth, setAuth]);

  if (isBootstrappingAuth) {
    return (
      <View className="flex-1 items-center justify-center bg-background">
        <ActivityIndicator color="#eab308" />
      </View>
    );
  }

  return (
    <NavigationContainer theme={navigationTheme}>
      {isAuthenticated ? <MainNavigator /> : <AuthNavigator />}
    </NavigationContainer>
  );
}
