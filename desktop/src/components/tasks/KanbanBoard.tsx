import type { Task } from "@shared/tasks";
import { CheckCircle2, Circle, Trash2 } from "lucide-react";
import { cn } from "@/utils/cn";
import { formatDate } from "@/utils/formatDate";

type KanbanBoardProps = {
  tasks: Task[];
  onToggleTask: (task: Task) => void;
  onDeleteTask: (taskId: string) => void;
  onEditTask: (task: Task) => void;
  onUpdateTask: (taskId: string, payload: { isCompleted: boolean }) => void;
};

type Column = {
  id: "todo" | "done";
  title: string;
  isCompleted: boolean;
};

const columns: Column[] = [
  { id: "todo", title: "To Do", isCompleted: false },
  { id: "done", title: "Completed", isCompleted: true },
];

export function KanbanBoard({
  tasks,
  onToggleTask,
  onDeleteTask,
  onEditTask,
  onUpdateTask,
}: KanbanBoardProps) {
  const byStatus = {
    todo: tasks.filter((task) => !task.isCompleted),
    done: tasks.filter((task) => task.isCompleted),
  };

  function handleDrop(event: React.DragEvent<HTMLDivElement>, targetCompleted: boolean) {
    event.preventDefault();
    const taskId = event.dataTransfer.getData("text/plain");
    if (!taskId) return;
    const task = tasks.find((item) => item.id === taskId);
    if (!task || task.isCompleted === targetCompleted) {
      return;
    }
    onUpdateTask(task.id, { isCompleted: targetCompleted });
  }

  return (
    <div className="grid grid-cols-2 gap-6">
      {columns.map((column) => (
        <div
          key={column.id}
          className="flex flex-col gap-3 rounded-xl border border-border/40 bg-[#1f1f1f]/50 p-4"
          onDragOver={(event) => event.preventDefault()}
          onDrop={(event) => handleDrop(event, column.isCompleted)}
        >
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text">{column.title}</h2>
            <span className="text-xs text-muted">{byStatus[column.id].length}</span>
          </div>

          <div className="flex flex-col gap-3">
            {byStatus[column.id].map((task) => (
              <div
                key={task.id}
                draggable
                onDragStart={(event) => {
                  event.dataTransfer.setData("text/plain", task.id);
                  event.dataTransfer.effectAllowed = "move";
                }}
                onClick={() => onEditTask(task)}
                className={cn(
                  "group flex items-center gap-3 rounded-lg border border-border/40 bg-[#252525]/60 px-4 py-3 transition-all hover:bg-[#252525]/70 hover:border-border/70 cursor-pointer",
                  task.isCompleted && "opacity-70"
                )}
              >
                <button
                  onClick={(event) => {
                    event.stopPropagation();
                    onToggleTask(task);
                  }}
                  className="flex h-6 w-6 items-center justify-center transition-transform active:scale-90"
                >
                  {task.isCompleted ? (
                    <CheckCircle2 size={20} className="text-accent" />
                  ) : (
                    <Circle size={20} className="text-[#555] group-hover:text-accent/50" />
                  )}
                </button>

                <div className="flex-1 min-w-0">
                  <p className="text-[14px] font-semibold text-text truncate leading-tight">
                    {task.title}
                  </p>
                  {task.description ? (
                    <p className="mt-1 text-xs text-muted line-clamp-2">
                      {task.description}
                    </p>
                  ) : null}
                  <p className="mt-2 text-[11px] text-muted/60">
                    Created {formatDate(task.createdAt)}
                  </p>
                </div>

                <button
                  onClick={(event) => {
                    event.stopPropagation();
                    onDeleteTask(task.id);
                  }}
                  className="rounded-md p-2 text-muted opacity-0 transition-all hover:bg-danger/20 hover:text-danger group-hover:opacity-100"
                >
                  <Trash2 size={16} />
                </button>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
