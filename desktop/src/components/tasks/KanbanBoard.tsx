import { useEffect, useMemo, useState } from "react";
import type { Task } from "@shared/tasks";
import { Trash2 } from "lucide-react";
import { cn } from "@shared-utils/cn";
import { formatDate } from "@shared-utils/formatDate";

type KanbanBoardProps = {
  tasks: Task[];
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
  onDeleteTask,
  onEditTask,
  onUpdateTask,
}: KanbanBoardProps) {
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [dragPosition, setDragPosition] = useState<{ x: number; y: number } | null>(null);
  const [dragOffset, setDragOffset] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const draggingTask = useMemo(
    () => (draggingId ? tasks.find((task) => task.id === draggingId) ?? null : null),
    [draggingId, tasks],
  );

  const byStatus = {
    todo: tasks.filter((task) => !task.isCompleted),
    done: tasks.filter((task) => task.isCompleted),
  };

  useEffect(() => {
    if (!draggingId) {
      return;
    }

    function handlePointerMove(event: PointerEvent) {
      setDragPosition({ x: event.clientX, y: event.clientY });
    }

    function handlePointerUp(event: PointerEvent) {
      const target = document.elementFromPoint(event.clientX, event.clientY);
      const column = target?.closest<HTMLElement>("[data-kanban-column]");
      const columnId = column?.dataset.kanbanColumn as Column["id"] | undefined;
      if (!columnId) {
        setDraggingId(null);
        setDragPosition(null);
        return;
      }

      const targetCompleted = columnId === "done";
      const task = tasks.find((item) => item.id === draggingId);
      if (task && task.isCompleted !== targetCompleted) {
        onUpdateTask(task.id, { isCompleted: targetCompleted });
      }

      setDraggingId(null);
      setDragPosition(null);
    }

    window.addEventListener("pointermove", handlePointerMove);
    window.addEventListener("pointerup", handlePointerUp);

    return () => {
      window.removeEventListener("pointermove", handlePointerMove);
      window.removeEventListener("pointerup", handlePointerUp);
    };
  }, [draggingId, onUpdateTask, tasks]);

  return (
    <div className="grid grid-cols-2 gap-6 min-h-[420px] relative">
      {columns.map((column) => (
        <div
          key={column.id}
          data-kanban-column={column.id}
          className={cn(
            "flex h-full flex-col gap-3 rounded-xl border border-border/40 bg-[#1f1f1f]/50 p-4 transition-colors",
            draggingId && "border-border/70 bg-[#232323]/60"
          )}
        >
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-text">{column.title}</h2>
            <span className="text-xs text-muted">{byStatus[column.id].length}</span>
          </div>

          <div className="flex flex-col gap-3">
            {byStatus[column.id].map((task) => (
              <div
                key={task.id}
                role="button"
                tabIndex={0}
                onPointerDown={(event) => {
                  event.preventDefault();
                  const rect = (event.currentTarget as HTMLElement).getBoundingClientRect();
                  setDragOffset({
                    x: event.clientX - rect.left,
                    y: event.clientY - rect.top,
                  });
                  setDraggingId(task.id);
                  setDragPosition({ x: event.clientX, y: event.clientY });
                }}
                onClick={() => onEditTask(task)}
                className={cn(
                  "group flex items-start gap-3 rounded-lg border border-border/40 bg-[#252525]/60 px-4 py-3 transition-all hover:bg-[#252525]/70 hover:border-border/70 cursor-pointer",
                  task.isCompleted && "opacity-70",
                  draggingId === task.id && "opacity-60 border-border/80"
                )}
              >
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

      {draggingTask && dragPosition ? (
        <div
          className="pointer-events-none fixed z-50 w-[320px] rounded-lg border border-border/60 bg-[#2a2a2a]/95 px-4 py-3 shadow-lg"
          style={{
            left: dragPosition.x - dragOffset.x,
            top: dragPosition.y - dragOffset.y,
          }}
        >
          <p className="text-[14px] font-semibold text-text truncate leading-tight">
            {draggingTask.title}
          </p>
          {draggingTask.description ? (
            <p className="mt-1 text-xs text-muted line-clamp-2">
              {draggingTask.description}
            </p>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
