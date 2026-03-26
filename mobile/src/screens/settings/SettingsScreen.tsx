import { useState } from "react";
import { View, Text, Pressable, Alert, ActivityIndicator } from "react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { RefreshCw, LogOut } from "lucide-react-native";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { ConfirmDialog } from "@/components/common";
import { useSync } from "@/hooks";
import { useAuthStore } from "@/stores/authStore";
import type { AppStackParamList } from "@/navigation/types";

type Navigation = StackNavigationProp<AppStackParamList, "Settings">;

export function SettingsScreen() {
  const navigation = useNavigation<Navigation>();
  const { resetAndSync, isSyncing } = useSync();
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const [showResetDialog, setShowResetDialog] = useState(false);
  const [showLogoutDialog, setShowLogoutDialog] = useState(false);

  const handleResetAndSync = async () => {
    setShowResetDialog(false);
    try {
      await resetAndSync();
      Alert.alert("Success", "All data synced from server successfully.");
    } catch (error) {
      Alert.alert("Error", "Failed to sync data. Please try again.");
    }
  };

  const handleLogout = () => {
    setShowLogoutDialog(false);
    clearAuth();
  };

  return (
    <ScreenContainer>
      <View className="flex-row items-center justify-between border-b border-border px-4 py-3">
        <Text className="text-xl font-semibold text-text">Settings</Text>
      </View>

      <View className="flex-1 px-4 pt-6">
        {/* Sync Section */}
        <View className="mb-8">
          <Text className="mb-3 text-sm font-semibold uppercase tracking-wider text-textMuted">
            Sync
          </Text>
          
          <Pressable
            onPress={() => setShowResetDialog(true)}
            disabled={isSyncing}
            className="flex-row items-center justify-between rounded-xl border border-danger/30 bg-danger/10 px-4 py-4"
          >
            <View className="flex-1 flex-row items-center">
              <View className="mr-3 rounded-full bg-danger/20 p-2">
                <RefreshCw size={20} color="#ff4444" />
              </View>
              <View className="flex-1">
                <Text className="text-base font-semibold text-danger">Reset & Sync</Text>
                <Text className="mt-1 text-sm text-danger/80">
                  Clear local data and pull all from server
                </Text>
              </View>
            </View>
            {isSyncing && <ActivityIndicator size="small" color="#ff4444" />}
          </Pressable>
        </View>

        {/* Account Section */}
        <View>
          <Text className="mb-3 text-sm font-semibold uppercase tracking-wider text-textMuted">
            Account
          </Text>
          
          <Pressable
            onPress={() => setShowLogoutDialog(true)}
            className="flex-row items-center rounded-xl border border-border bg-surfaceSecondary px-4 py-4"
          >
            <View className="mr-3 rounded-full bg-surface p-2">
              <LogOut size={20} color="#a0a0a0" />
            </View>
            <Text className="text-base font-medium text-text">Log Out</Text>
          </Pressable>
        </View>
      </View>

      <ConfirmDialog
        visible={showResetDialog}
        title="Reset & Sync"
        description="This will clear all local data and pull everything from the server. Your data on the server will not be affected."
        confirmLabel="Reset & Sync"
        destructive
        onConfirm={handleResetAndSync}
        onCancel={() => setShowResetDialog(false)}
      />

      <ConfirmDialog
        visible={showLogoutDialog}
        title="Log Out"
        description="Are you sure you want to log out?"
        confirmLabel="Log Out"
        onConfirm={handleLogout}
        onCancel={() => setShowLogoutDialog(false)}
      />
    </ScreenContainer>
  );
}
