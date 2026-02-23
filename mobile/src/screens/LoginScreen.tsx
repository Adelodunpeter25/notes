import React from "react";
import { View, Text, StyleSheet, TouchableOpacity } from "react-native";
import { colors } from "@/theme/colors";

export function LoginScreen({ navigation }: any) {
    return (
        <View style={styles.container}>
            <Text style={styles.title}>Notes App</Text>
            <TouchableOpacity
                style={styles.button}
                onPress={() => navigation.navigate("Main")}
            >
                <Text style={styles.buttonText}>Log In</Text>
            </TouchableOpacity>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: colors.background,
        alignItems: "center",
        justifyContent: "center",
        padding: 20,
    },
    title: {
        fontSize: 32,
        fontWeight: "bold",
        color: colors.text,
        marginBottom: 40,
    },
    button: {
        backgroundColor: colors.accent,
        paddingHorizontal: 40,
        paddingVertical: 12,
        borderRadius: 8,
    },
    buttonText: {
        color: "#000",
        fontWeight: "bold",
        fontSize: 16,
    },
});
