import { View, Text, Pressable, ScrollView } from "react-native";
import { ChevronLeft, ChevronRight } from "lucide-react-native";
import { useState, useMemo } from "react";
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameMonth, isToday, isSameDay, addMonths, subMonths, startOfWeek, endOfWeek } from "date-fns";
import type { Task } from "@shared/tasks";

type CalendarViewProps = {
  tasks: Task[];
  onSelectDate: (date: Date, tasks: Task[]) => void;
};

export function CalendarView({ tasks, onSelectDate }: CalendarViewProps) {
  const [currentMonth, setCurrentMonth] = useState(new Date());

  const tasksByDate = useMemo(() => {
    const map = new Map<string, Task[]>();
    tasks.forEach((task) => {
      if (!task.dueDate) return;
      const dateKey = format(new Date(task.dueDate), "yyyy-MM-dd");
      if (!map.has(dateKey)) {
        map.set(dateKey, []);
      }
      map.get(dateKey)!.push(task);
    });
    return map;
  }, [tasks]);

  const calendarDays = useMemo(() => {
    const start = startOfWeek(startOfMonth(currentMonth));
    const end = endOfWeek(endOfMonth(currentMonth));
    return eachDayOfInterval({ start, end });
  }, [currentMonth]);

  const getTasksForDate = (date: Date) => {
    const dateKey = format(date, "yyyy-MM-dd");
    return tasksByDate.get(dateKey) || [];
  };

  const handlePrevMonth = () => setCurrentMonth(subMonths(currentMonth, 1));
  const handleNextMonth = () => setCurrentMonth(addMonths(currentMonth, 1));

  return (
    <View className="flex-1 bg-background">
      <View className="border-b border-border px-4 py-3">
        <View className="flex-row items-center justify-between">
          <Pressable onPress={handlePrevMonth} className="p-2">
            <ChevronLeft size={20} color="#eab308" />
          </Pressable>
          <Text className="text-base font-semibold text-text">
            {format(currentMonth, "MMMM yyyy")}
          </Text>
          <Pressable onPress={handleNextMonth} className="p-2">
            <ChevronRight size={20} color="#eab308" />
          </Pressable>
        </View>
      </View>

      <ScrollView className="flex-1">
        <View className="px-4 py-2">
          <View className="flex-row mb-2">
            {["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((day) => (
              <View key={day} className="flex-1 items-center py-2">
                <Text className="text-xs font-medium text-textMuted">{day}</Text>
              </View>
            ))}
          </View>

          <View className="flex-row flex-wrap">
            {calendarDays.map((day, index) => {
              const dayTasks = getTasksForDate(day);
              const isCurrentMonth = isSameMonth(day, currentMonth);
              const totalCount = dayTasks.length;
              
              let bgColor = "";
              if (totalCount > 0) {
                if (totalCount <= 3) {
                  bgColor = "bg-green-500/20";
                } else if (totalCount <= 7) {
                  bgColor = "bg-accent/20";
                } else {
                  bgColor = "bg-danger/20";
                }
              }

              return (
                <Pressable
                  key={index}
                  onPress={() => {
                    if (dayTasks.length > 0) {
                      onSelectDate(day, dayTasks);
                    }
                  }}
                  className="w-[14.28%] aspect-square p-1"
                >
                  <View className={`flex-1 items-center justify-center rounded-lg ${bgColor}`}>
                    <Text
                      className={`text-sm ${
                        !isCurrentMonth ? "text-textMuted/40" : "text-text"
                      }`}
                    >
                      {format(day, "d")}
                    </Text>
                    {totalCount > 0 && (
                      <Text className="mt-0.5 text-[10px] font-semibold text-text">{totalCount}</Text>
                    )}
                  </View>
                </Pressable>
              );
            })}
          </View>
        </View>
      </ScrollView>
    </View>
  );
}
