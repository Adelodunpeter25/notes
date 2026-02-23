import { useMemo, useState } from "react";
import { Pressable, Text, TextInput, View } from "react-native";
import { Eye, EyeOff } from "lucide-react-native";
import { useNavigation } from "@react-navigation/native";
import type { StackNavigationProp } from "@react-navigation/stack";

import { Button, AppleNotesIcon } from "@/components/common";
import { ScreenContainer } from "@/components/layout/ScreenContainer";
import { useSignupMutation } from "@/hooks";
import type { AuthStackParamList } from "@/navigation/types";

type Navigation = StackNavigationProp<AuthStackParamList, "Signup">;

export function SignupScreen() {
  const navigation = useNavigation<Navigation>();
  const signupMutation = useSignupMutation();

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const nameValue = name.trim();
  const emailValue = email.trim();

  const errors = useMemo(() => {
    const nextErrors: { name?: string; email?: string; password?: string } = {};

    if (!nameValue) {
      nextErrors.name = "Name is required.";
    }
    if (!emailValue) {
      nextErrors.email = "Email is required.";
    } else if (!/^\S+@\S+\.\S+$/.test(emailValue)) {
      nextErrors.email = "Enter a valid email address.";
    }
    if (!password) {
      nextErrors.password = "Password is required.";
    } else if (password.length < 8) {
      nextErrors.password = "Password must be at least 8 characters.";
    }

    return nextErrors;
  }, [nameValue, emailValue, password]);

  const isValid = !errors.name && !errors.email && !errors.password;

  const submit = () => {
    setSubmitted(true);
    if (!isValid || signupMutation.isPending) {
      return;
    }

    signupMutation.mutate({ name: nameValue, email: emailValue, password });
  };

  return (
    <ScreenContainer className="px-5">
      <View className="flex-1 items-center justify-center">
        <View className="w-full max-w-[420px] rounded-2xl border border-border bg-surface p-5">
          <View className="mb-5 items-center">
            <AppleNotesIcon />
            <Text className="mt-3 text-xl font-semibold text-text">Create account</Text>
            <Text className="mt-1 text-sm text-textMuted">Start your notes workspace.</Text>
          </View>

          <View>
            <View className="mb-3">
              <TextInput
                value={name}
                onChangeText={setName}
                placeholder="Name"
                autoCapitalize="words"
                placeholderTextColor="#636366"
                className={[
                  "rounded-xl border bg-background px-4 py-3 text-[16px] text-text",
                  submitted && errors.name ? "border-red-500" : "border-border",
                ].join(" ")}
              />
              {submitted && errors.name ? (
                <Text className="mt-1 px-1 text-[12px] text-red-500">{errors.name}</Text>
              ) : null}
            </View>

            <View className="mb-3">
              <TextInput
                value={email}
                onChangeText={setEmail}
                placeholder="Email"
                keyboardType="email-address"
                autoCapitalize="none"
                autoCorrect={false}
                placeholderTextColor="#636366"
                className={[
                  "rounded-xl border bg-background px-4 py-3 text-[16px] text-text",
                  submitted && errors.email ? "border-red-500" : "border-border",
                ].join(" ")}
              />
              {submitted && errors.email ? (
                <Text className="mt-1 px-1 text-[12px] text-red-500">{errors.email}</Text>
              ) : null}
            </View>

            <View className="mb-3">
              <View
                className={[
                  "flex-row items-center rounded-xl border bg-background px-4",
                  submitted && errors.password ? "border-red-500" : "border-border",
                ].join(" ")}
              >
                <TextInput
                  value={password}
                  onChangeText={setPassword}
                  placeholder="Password"
                  secureTextEntry={!showPassword}
                  autoCapitalize="none"
                  autoCorrect={false}
                  placeholderTextColor="#636366"
                  className="flex-1 py-3 text-[16px] text-text"
                />
                <Pressable
                  onPress={() => setShowPassword((value) => !value)}
                  hitSlop={8}
                  className="ml-3"
                >
                  {showPassword ? <EyeOff size={18} color="#a0a0a0" /> : <Eye size={18} color="#a0a0a0" />}
                </Pressable>
              </View>
              {submitted && errors.password ? (
                <Text className="mt-1 px-1 text-[12px] text-red-500">{errors.password}</Text>
              ) : null}
            </View>

            {signupMutation.isError ? (
              <Text className="mb-3 text-sm text-red-500">{signupMutation.error.message}</Text>
            ) : null}

            <Button
              onPress={submit}
              title={signupMutation.isPending ? "Creating..." : "Sign up"}
              disabled={!isValid || signupMutation.isPending}
            />
          </View>

          <View className="mt-4 flex-row items-center justify-center">
            <Text className="text-sm text-textMuted">Already have an account? </Text>
            <Pressable onPress={() => navigation.navigate("Login")}>
              <Text className="text-sm font-medium text-accent">Login</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </ScreenContainer>
  );
}
