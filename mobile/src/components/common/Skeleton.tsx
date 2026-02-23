import React, { useEffect } from "react";
import { View, Animated, type DimensionValue } from "react-native";
import { cn } from "@/utils/cn";

interface SkeletonProps {
    className?: string;
    width?: DimensionValue;
    height?: DimensionValue;
}

export function Skeleton({ className, width, height }: SkeletonProps) {
    const animatedValue = new Animated.Value(0);

    useEffect(() => {
        Animated.loop(
            Animated.sequence([
                Animated.timing(animatedValue, {
                    toValue: 1,
                    duration: 1000,
                    useNativeDriver: true,
                }),
                Animated.timing(animatedValue, {
                    toValue: 0,
                    duration: 1000,
                    useNativeDriver: true,
                }),
            ])
        ).start();
    }, []);

    const opacity = animatedValue.interpolate({
        inputRange: [0, 1],
        outputRange: [0.3, 0.7],
    });

    return (
        <Animated.View
            style={[{ width, height, opacity }]}
            className={cn("bg-surfaceSecondary rounded-md", className)}
        />
    );
}
