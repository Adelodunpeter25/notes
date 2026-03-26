import { NavigationContainer } from "@react-navigation/native";
import { createStackNavigator } from "@react-navigation/stack";

import type { AppStackParamList, AuthStackParamList } from "./types";
import { LoginScreen, SignupScreen } from "@/screens/auth";
import { DashboardScreen, FolderDetailsScreen } from "@/screens/dashboard";
import { NoteEditorScreen } from "@/screens/editor";
import { SearchScreen } from "@/screens/search";
import { TrashScreen } from "@/screens/trash";
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
      <AppStack.Screen name="Trash" component={TrashScreen} />
    </AppStack.Navigator>
  );
}

export function RootNavigator() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  return (
    <NavigationContainer theme={navigationTheme}>
      {isAuthenticated ? <MainNavigator /> : <AuthNavigator />}
    </NavigationContainer>
  );
}
