import { useState } from "react";
import { View, Text, Pressable, ActivityIndicator } from "react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";
import { RefreshCw, LogOut, Clock, ChevronLeft } from "lucide-react-native";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { ConfirmDialog, ToastContainer } from "@/components/common";
import { useSync, useToast } from "@/hooks";
import { useAuthStore } from "@/stores/authStore";
import type { AppStackParamList } from "@/navigation/types";

type Navigation = StackNavigationProp<AppStackParamList, "Settings">;

export function SettingsScreen() {
  const navigation = useNavigation<Navigation>();
  const { resetAndSync, resetSyncCursor, syncNow, isSyncing, isResetting } = useSync();
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const [showResetDialog, setShowResetDialog] = useState(false);
  const [showLogoutDialog, setShowLogoutDialog] = useState(false);
  const { toasts, showToast, dismissToast } = useToast();

  const handleResetAndSync = async () => {
    setShowResetDialog(false);
    try {
      await resetAndSync();
      showToast("All data synced from server successfully.", "success");
    } catch (error) {
      showToast("Failed to sync data. Please try again.", "error");
    }
  };

  const handleResetSyncTime = async () => {
    try {
      await resetSyncCursor();
      await syncNow();
      showToast("Sync cursor cleared — full sync triggered.", "success");
    } catch (error) {
      showToast("Failed to reset sync time. Please try again.", "error");
    }
  };

  const handleLogout = () => {
    setShowLogoutDialog(false);
    clearAuth();
  };

  return (
    <ScreenContainer>
      <View className="flex-row items-center border-b border-border px-4 py-3">
        <Pressable
          onPress={() => navigation.goBack()}
          className="flex-row items-center rounded-md py-1 pr-2"
          hitSlop={15}
        >
          <ChevronLeft size={20} color="#eab308" />
          <Text className="text-sm font-medium text-accent">Back</Text>
        </Pressable>
        <Text className="ml-4 text-xl font-semibold text-text">Settings</Text>
      </View>

      <View className="flex-1 px-4 pt-6">
        {/* Sync Section */}
        <View className="mb-8">
          <Text className="mb-3 text-sm font-semibold uppercase tracking-wider text-textMuted">
            Sync
          </Text>

          <Pressable
            onPress={handleResetSyncTime}
            disabled={isSyncing}
            className="mb-3 flex-row items-center justify-between rounded-xl border border-border bg-surfaceSecondary px-4 py-4"
          >
            <View className="flex-1 flex-row items-center">
              <View className="mr-3 rounded-full bg-accent/20 p-2">
                <Clock size={20} color="#f2c94c" />
              </View>
              <View className="flex-1">
                <Text className="text-base font-semibold text-text">Reset Last Sync Time</Text>
                <Text className="mt-1 text-sm text-textMuted">
                  Clear cursor so next sync pushes all data
                </Text>
              </View>
            </View>
            {isSyncing && <ActivityIndicator size="small" color="#f2c94c" />}
          </Pressable>

          <Pressable
            onPress={() => setShowResetDialog(true)}
            disabled={isResetting || isSyncing}
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
            {isResetting && <ActivityIndicator size="small" color="#ff4444" />}
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

      <ToastContainer toasts={toasts} onDismiss={dismissToast} />
    </ScreenContainer>
  );
}
