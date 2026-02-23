import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";
import AsyncStorage from "@react-native-async-storage/async-storage";
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
const AUTH_STORAGE_KEY = "auth-storage";

function AuthNavigator() {
  return (
    <AuthStack.Navigator
      initialRouteName="Login"
      screenOptions={{
        headerShown: false,
        animationEnabled: false,
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
        animationEnabled: false,
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

    const fallbackTimer = setTimeout(() => {
      if (active) {
        setIsBootstrappingAuth(false);
      }
    }, 4000);

    async function bootstrapAuth() {
      try {
        const raw = await AsyncStorage.getItem(AUTH_STORAGE_KEY);
        if (!raw) {
          return;
        }

        const parsed = JSON.parse(raw) as { state?: { token?: string | null } };
        const token = parsed?.state?.token;

        if (!token) {
          return;
        }

        const response = await apiClient.instance.get<AuthUser>("/auth/me", {
          headers: { Authorization: `Bearer ${token}` },
        });

        setAuth({ token, user: response.data });
      } catch {
        clearAuth();
      } finally {
        if (active) {
          clearTimeout(fallbackTimer);
          setIsBootstrappingAuth(false);
        }
      }
    }

    void bootstrapAuth();

    return () => {
      active = false;
      clearTimeout(fallbackTimer);
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
