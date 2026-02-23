import "@/theme/global.css";
import "react-native-gesture-handler";
import React from "react";
import { View, Text } from "react-native";
import { StatusBar } from "expo-status-bar";
import { SafeAreaProvider, SafeAreaView } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { QueryClientProvider } from "@tanstack/react-query";

import { queryClient } from "@/api/queryClient";
import { colors } from "@/theme/colors";

export default function App() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <QueryClientProvider client={queryClient}>
        <SafeAreaProvider>
          <SafeAreaView className="flex-1 bg-[#1e1e1e]">
            <View className="flex-1 items-center justify-center">
              <Text className="text-3xl font-bold text-yellow-500">
                Notes App
              </Text>
              <Text className="mt-2 text-gray-400">
                Mobile development started!
              </Text>
            </View>
            <StatusBar style="light" backgroundColor="#252525" />
          </SafeAreaView>
        </SafeAreaProvider>
      </QueryClientProvider>
    </GestureHandlerRootView>
  );
}
