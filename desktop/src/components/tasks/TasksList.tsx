import { useState } from "react";
import { CheckCircle2, Circle, Trash2, Plus, Calendar, Clock, Columns2 } from "lucide-react";
import type { Task, CreateTaskPayload } from "@shared/tasks";
import { cn } from "@/utils/cn";
import { formatDate } from "@/utils/formatDate";
import { Skeleton, EmptyState, Button } from "@/components/common";
import { TaskModal } from "./TaskModal";
import { KanbanBoard } from "./KanbanBoard";
import { useUiStore } from "@/stores/uiStore";

type TasksListProps = {
  tasks: Task[];
  isLoading?: boolean;
  onToggleTask: (task: Task) => void;
  onDeleteTask: (taskId: string) => void;
  onCreateTask: (payload: CreateTaskPayload) => void;
  onUpdateTask: (taskId: string, payload: any) => void;
};

export function TasksList({
  tasks,
  isLoading,
  onToggleTask,
  onDeleteTask: propOnDeleteTask,
  onCreateTask,
  onUpdateTask,
}: TasksListProps) {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingTask, setEditingTask] = useState<Task | null>(null);
  const tasksView = useUiStore((state) => state.tasksView);
  const setTasksView = useUiStore((state) => state.setTasksView);
  const isKanban = tasksView === "kanban";

  const handleCreateNew = () => {
    setEditingTask(null);
    setIsModalOpen(true);
  };

  const handleEditTask = (task: Task) => {
    setEditingTask(task);
    setIsModalOpen(true);
  };

  const handleSaveTask = (payload: CreateTaskPayload) => {
    if (editingTask) {
      onUpdateTask(editingTask.id, payload);
    } else {
      onCreateTask(payload);
    }
    setIsModalOpen(false);
  };

  if (isLoading) {
    return (
      <div className="flex flex-col gap-2 p-6">
        <Skeleton className="h-20 w-full rounded-xl bg-white/5" />
        <Skeleton className="h-20 w-full rounded-xl bg-white/5" />
        <Skeleton className="h-20 w-full rounded-xl bg-white/5" />
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col bg-background relative overflow-hidden">
      <div className="flex items-center justify-between px-8 py-6 sticky top-0 z-10 bg-background/80 backdrop-blur-md">
        <div>
          <h1 className="text-2xl font-bold text-text">Tasks</h1>
          <p className="text-sm text-muted mt-1">You have {tasks.filter(t => !t.isCompleted).length} tasks remaining</p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            onClick={() => setTasksView(isKanban ? "list" : "kanban")}
            variant="secondary"
            className="rounded-full px-4 gap-2"
          >
            <Columns2 size={16} />
            <span>{isKanban ? "List" : "Kanban"}</span>
          </Button>
          <Button onClick={handleCreateNew} className="rounded-full px-6 gap-2">
            <Plus size={18} />
            <span>Add Task</span>
          </Button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto px-8 pb-12">
        <div className="max-w-5xl mx-auto w-full">
          {tasks.length === 0 ? (
            <EmptyState
              variant="simple"
              title="All caught up!"
              description="You don't have any pending tasks. Create one to get started."
            />
          ) : isKanban ? (
            <KanbanBoard
              tasks={tasks}
              onDeleteTask={propOnDeleteTask}
              onEditTask={handleEditTask}
              onUpdateTask={(taskId, payload) => onUpdateTask(taskId, payload)}
            />
          ) : (
            <div className="space-y-3">
              {tasks.map((task) => (
                <div
                  key={task.id}
                  onClick={() => handleEditTask(task)}
                  className={cn(
                    "group flex items-center gap-3 rounded-lg border border-border/40 bg-[#252525]/40 px-3 py-2 transition-all hover:bg-[#252525]/55 hover:border-border/70 cursor-pointer",
                    task.isCompleted && "opacity-60 grayscale-[0.3]"
                  )}
                >
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onToggleTask(task);
                    }}
                    className="flex h-5 w-5 items-center justify-center transition-transform active:scale-90"
                  >
                    {task.isCompleted ? (
                      <CheckCircle2 size={18} className="text-accent" />
                    ) : (
                      <Circle size={18} className="text-[#555] group-hover:text-accent/50" />
                    )}
                  </button>

                  <div className="flex-1 min-w-0 py-0.5">
                    <div className="flex items-center justify-between gap-4">
                      <p
                        className={cn(
                          "text-[14px] font-semibold text-text truncate leading-tight",
                          task.isCompleted && "line-through text-muted font-medium"
                        )}
                      >
                        {task.title}
                      </p>
                    </div>
                    
                    {task.description ? (
                      <p className="mt-1 text-[13px] text-muted line-clamp-2 leading-relaxed">
                        {task.description}
                      </p>
                    ) : null}

                    <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-2">
                      <div className="flex items-center gap-1.5 text-[11px] font-medium text-muted/60">
                        <Clock size={12} />
                        <span>Created {formatDate(task.createdAt)}</span>
                      </div>

                      {task.dueDate && (
                        <div className={cn(
                          "flex items-center gap-1.5 text-[11px] font-bold px-2 py-0.5 rounded-full",
                          new Date(task.dueDate) < new Date() && !task.isCompleted
                            ? "bg-danger/10 text-danger"
                            : "bg-accent/10 text-accent"
                        )}>
                          <Calendar size={12} />
                          <span>Expires {formatDate(task.dueDate)}</span>
                        </div>
                      )}
                    </div>
                  </div>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      propOnDeleteTask(task.id);
                    }}
                    className="mt-0.5 rounded-md p-2 text-muted opacity-0 transition-all hover:bg-danger/20 hover:text-danger group-hover:opacity-100"
                  >
                    <Trash2 size={18} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <TaskModal
        open={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        onSave={handleSaveTask}
        initialTask={editingTask}
      />

    </div>
  );
}
