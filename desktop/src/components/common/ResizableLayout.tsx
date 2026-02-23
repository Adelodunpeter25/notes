import { useEffect, useRef, type PropsWithChildren, type ReactNode } from "react";
import {
  Group,
  Panel,
  Separator,
  type GroupProps,
  type PanelImperativeHandle,
} from "react-resizable-panels";

type ResizableSectionProps = PropsWithChildren<{
  defaultSize?: number;
  minSize?: number;
  maxSize?: number;
  className?: string;
}>;

type ResizableLayoutProps = {
  left: ReactNode;
  center?: ReactNode;
  right?: ReactNode;
  leftCollapsed?: boolean;
  direction?: GroupProps["orientation"];
  className?: string;
  leftPanel?: Omit<ResizableSectionProps, "children">;
  centerPanel?: Omit<ResizableSectionProps, "children">;
  rightPanel?: Omit<ResizableSectionProps, "children">;
};

function panelClassName(className?: string): string {
  return ["h-full overflow-hidden", className].filter(Boolean).join(" ");
}

export function ResizableLayout({
  left,
  center,
  right,
  leftCollapsed = false,
  direction = "horizontal",
  className,
  leftPanel,
  centerPanel,
  rightPanel,
}: ResizableLayoutProps) {
  const leftPanelRef = useRef<PanelImperativeHandle | null>(null);
  const leftDefaultSize = leftPanel?.defaultSize ?? 24;

  useEffect(() => {
    if (!leftPanelRef.current) {
      return;
    }

    if (leftCollapsed) {
      leftPanelRef.current.collapse();
    } else {
      leftPanelRef.current.expand();
    }
  }, [leftCollapsed]);

  return (
    <Group
      orientation={direction}
      disableCursor
      className={[
        "h-full min-h-[70vh] w-full bg-surface",
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      <Panel
        id="panel-sidebar"
        panelRef={leftPanelRef}
        collapsible
        collapsedSize={0}
        defaultSize={leftDefaultSize}
        minSize={leftPanel?.minSize ?? 0}
        maxSize={leftPanel?.maxSize}
        className={panelClassName([
          "app-sidebar-panel",
          leftCollapsed ? "sidebar-panel-collapsed" : "sidebar-panel-expanded",
          leftPanel?.className,
        ]
          .filter(Boolean)
          .join(" "))}
      >
        <div
          className={[
            "h-full sidebar-content-transition",
            leftCollapsed ? "sidebar-content-hidden" : "sidebar-content-visible",
          ].join(" ")}
          aria-hidden={leftCollapsed}
        >
          {left}
        </div>
      </Panel>

      {center && (
        <Separator
          id="resize-handle-1"
          className={[
            "w-px cursor-col-resize bg-border transition-colors duration-200 ease-apple hover:bg-accent/60 active:bg-accent/80 sidebar-separator-transition",
            leftCollapsed ? "opacity-0 pointer-events-none w-0 sidebar-separator-hidden" : "sidebar-separator-visible",
          ].join(" ")}
        />
      )}

      {center && (
        <Panel
          id="panel-center"
          defaultSize={centerPanel?.defaultSize ?? 28}
          minSize={centerPanel?.minSize ?? 20}
          maxSize={leftCollapsed ? (centerPanel?.defaultSize ?? 28) : (centerPanel?.maxSize ?? 40)}
          className={panelClassName(centerPanel?.className)}
        >
          {center}
        </Panel>
      )}

      {right && (
        <Separator id="resize-handle-2" className="w-px cursor-col-resize bg-border transition-colors duration-200 ease-apple hover:bg-accent/60 active:bg-accent/80" />
      )}

      {right && (
        <Panel
          id="panel-right"
          defaultSize={rightPanel?.defaultSize ?? 55}
          minSize={rightPanel?.minSize ?? 35}
          maxSize={rightPanel?.maxSize}
          className={panelClassName(rightPanel?.className)}
        >
          {right}
        </Panel>
      )}
    </Group>
  );
}
