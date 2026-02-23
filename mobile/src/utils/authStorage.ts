import AsyncStorage from "@react-native-async-storage/async-storage";

const AUTH_TOKEN_KEY = "notes_access_token";

export const authStorage = {
  key: AUTH_TOKEN_KEY,
  getToken: async (): Promise<string | null> => AsyncStorage.getItem(AUTH_TOKEN_KEY),
  setToken: async (token: string): Promise<void> => {
    await AsyncStorage.setItem(AUTH_TOKEN_KEY, token);
  },
  clearToken: async (): Promise<void> => {
    await AsyncStorage.removeItem(AUTH_TOKEN_KEY);
  },
};

