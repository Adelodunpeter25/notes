import { Text, View } from "react-native";

import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { Button } from "@/components/common";
import { useAuthStore } from "@/stores/authStore";

export function DashboardScreen() {
  const clearAuth = useAuthStore((state) => state.clearAuth);
  const user = useAuthStore((state) => state.user);

  return (
    <ScreenContainer className="px-5">
      <View className="flex-1 items-center justify-center">
        <Text className="text-2xl font-semibold text-text">Notes</Text>
        <Text className="mt-2 text-sm text-textMuted">
          Signed in as {user?.name || user?.email}
        </Text>
        <Button
          onPress={clearAuth}
          title="Logout"
          variant="outline"
          className="mt-6 w-full max-w-[220px]"
        />
      </View>
    </ScreenContainer>
  );
}
