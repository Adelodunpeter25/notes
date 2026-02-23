import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";
import { ActivityIndicator, View } from "react-native";

import type { AppStackParamList, AuthStackParamList } from "./types";
import { LoginScreen, SignupScreen } from "@/screens/auth";
import { DashboardScreen, FolderDetailsScreen } from "@/screens/dashboard";
import { NoteEditorScreen } from "@/screens/editor";
import { SearchScreen } from "@/screens/search";
import { useAuthStore } from "@/stores/authStore";
import { colors } from "@/theme/colors";
import { navigationTheme } from "@/theme/navigationTheme";

const AuthStack = createStackNavigator<AuthStackParamList>();
const AppStack = createStackNavigator<AppStackParamList>();

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
  const hasHydrated = useAuthStore((state) => state.hasHydrated);

  if (!hasHydrated) {
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
