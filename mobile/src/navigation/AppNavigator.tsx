import React from "react";
import { createStackNavigator } from "@react-navigation/stack";
import { LoginScreen } from "@/screens/LoginScreen";
import { colors } from "@/theme/colors";

const Stack = createStackNavigator();

export function AppNavigator() {
    return (
        <Stack.Navigator
            screenOptions={{
                headerStyle: {
                    backgroundColor: colors.surface,
                    elevation: 0,
                    shadowOpacity: 0,
                },
                headerTintColor: colors.text,
                headerTitleStyle: {
                    fontWeight: "bold",
                },
                cardStyle: { backgroundColor: colors.background },
            }}
        >
            <Stack.Screen
                name="Login"
                component={LoginScreen}
                options={{ headerShown: false }}
            />
            {/* We will add Folder and Note screens here next */}
        </Stack.Navigator>
    );
}
