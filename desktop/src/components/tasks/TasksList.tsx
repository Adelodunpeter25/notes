import { useState } from "react";
import { CheckCircle2, Circle, Trash2, Plus, Calendar } from "lucide-react";
import type { Task } from "@shared/tasks";
import { cn } from "@/utils/cn";
import { formatDate } from "@/utils/formatDate";
import { Skeleton, ConfirmDialog, EmptyState } from "@/components/common";

type TasksListProps = {
  tasks: Task[];
  isLoading?: boolean;
  onToggleTask: (task: Task) => void;
  onDeleteTask: (taskId: string) => void;
  onCreateTask: (title: string) => void;
  onUpdateTask: (taskId: string, payload: any) => void;
};

export function TasksList({
  tasks,
  isLoading,
  onToggleTask,
  onDeleteTask: propOnDeleteTask,
  onCreateTask,
}: TasksListProps) {
  const [newTaskTitle, setNewTaskTitle] = useState("");
  const [taskToDelete, setTaskToDelete] = useState<string | null>(null);

  const handleCreateTask = (e: React.FormEvent) => {
    e.preventDefault();
    if (newTaskTitle.trim()) {
      onCreateTask(newTaskTitle.trim());
      setNewTaskTitle("");
    }
  };

  const handleConfirmDelete = () => {
    if (taskToDelete) {
      propOnDeleteTask(taskToDelete);
      setTaskToDelete(null);
    }
  };

  if (isLoading) {
    return (
      <div className="flex flex-col gap-2 p-6">
        <Skeleton className="h-16 w-full rounded-xl bg-white/5" />
        <Skeleton className="h-16 w-full rounded-xl bg-white/5" />
        <Skeleton className="h-16 w-full rounded-xl bg-white/5" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col bg-background relative overflow-hidden">
      <div className="flex-1 overflow-y-auto p-6 pt-10">
        <form onSubmit={handleCreateTask} className="mb-8 relative group max-w-2xl mx-auto">
          <input
            type="text"
            value={newTaskTitle}
            onChange={(e) => setNewTaskTitle(e.target.value)}
            placeholder="Add a new task..."
            className="w-full rounded-xl border border-border/50 bg-white/5 px-4 py-3.5 pl-11 text-sm outline-none transition-all focus:border-accent/50 focus:bg-white/10"
          />
          <Plus className="absolute left-4 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-accent transition-colors" size={20} />
          {newTaskTitle.trim() && (
            <button
              type="submit"
              className="absolute right-3 top-1/2 -translate-y-1/2 rounded-lg bg-accent px-3 py-1 text-xs font-semibold text-background transition-transform active:scale-95"
            >
              Add
            </button>
          )}
        </form>

        <div className="max-w-2xl mx-auto">
          {tasks.length === 0 ? (
            <EmptyState
              title="All caught up!"
              description="You don't have any pending tasks. Create one to get started."
            />
          ) : (
            <div className="space-y-3">
              {tasks.map((task) => (
                <div
                  key={task.id}
                  className={cn(
                    "group flex items-center gap-4 rounded-xl border border-border/40 bg-white/5 p-4 transition-all hover:bg-white/10",
                    task.isCompleted && "opacity-60 grayscale-[0.5]"
                  )}
                >
                  <button
                    onClick={() => onToggleTask(task)}
                    className="flex h-6 w-6 items-center justify-center transition-transform active:scale-90"
                  >
                    {task.isCompleted ? (
                      <CheckCircle2 size={24} className="text-accent" />
                    ) : (
                      <Circle size={24} className="text-muted group-hover:text-accent/50" />
                    )}
                  </button>

                  <div className="flex-1 min-w-0">
                    <p
                      className={cn(
                        "text-sm font-medium text-text transition-all truncate",
                        task.isCompleted && "line-through text-muted"
                      )}
                    >
                      {task.title}
                    </p>
                    {task.dueDate && (
                      <div className="mt-1 flex items-center gap-1.5 text-[11px] text-accent/80 font-medium">
                        <Calendar size={12} />
                        <span>{formatDate(task.dueDate)}</span>
                      </div>
                    )}
                  </div>

                  <button
                    onClick={() => setTaskToDelete(task.id)}
                    className="rounded-lg p-2 text-muted opacity-0 transition-all hover:bg-danger/20 hover:text-danger group-hover:opacity-100"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <ConfirmDialog
        open={taskToDelete !== null}
        title="Delete Task?"
        description="This action cannot be undone."
        confirmLabel="Delete"
        destructive
        onConfirm={handleConfirmDelete}
        onCancel={() => setTaskToDelete(null)}
      />
    </div>
  );
}
