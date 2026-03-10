import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { Task, CreateTaskPayload, UpdateTaskPayload } from "@shared/tasks";
import {
  createTaskLocal,
  enqueueTaskDelete,
  enqueueTaskUpsert,
  listTasksLocal,
  markTaskDeletedLocal,
  updateTaskLocal,
} from "@/db";

const tasksKeys = {
  all: ["tasks"] as const,
  list: (params?: { q?: string }) => [...tasksKeys.all, "list", params] as const,
};

export function useTasksQuery(params?: { q?: string }) {
  return useQuery({
    queryKey: tasksKeys.list(params),
    queryFn: () => listTasksLocal(params),
  });
}

export function useCreateTaskMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: CreateTaskPayload) => {
      const created = await createTaskLocal(payload);
      try {
        await enqueueTaskUpsert(created.id, {
          title: created.title,
          description: created.description,
          isCompleted: created.isCompleted,
          dueDate: created.dueDate,
        });
      } catch (error) {
        console.error("Failed to enqueue task create for sync:", error);
      }
      return created;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: tasksKeys.all });
    },
  });
}

export function useUpdateTaskMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ taskId, payload }: { taskId: string; payload: UpdateTaskPayload }) => {
      const updated = await updateTaskLocal(taskId, payload);
      if (!updated) {
        throw new Error("Task not found");
      }
      try {
        await enqueueTaskUpsert(taskId, payload);
      } catch (error) {
        console.error("Failed to enqueue task update for sync:", error);
      }
      return updated;
    },
    onSuccess: (updatedTask) => {
      queryClient.setQueriesData<Task[] | undefined>({ queryKey: tasksKeys.all }, (current) => {
        if (!current) return current;
        return current.map((t) => (t.id === updatedTask.id ? updatedTask : t));
      });
      queryClient.invalidateQueries({ queryKey: tasksKeys.all });
    },
  });
}

export function useDeleteTaskMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (taskId: string) => {
      await markTaskDeletedLocal(taskId);
      try {
        await enqueueTaskDelete(taskId);
      } catch (error) {
        console.error("Failed to enqueue task delete for sync:", error);
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: tasksKeys.all });
    },
  });
}

export { tasksKeys };
