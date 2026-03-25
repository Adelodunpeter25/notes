import { useDashboardData } from "./useDashboardData";
import { useDashboardSelection } from "./useDashboardSelection";

export function useDashboardNotes() {
  const selection = useDashboardSelection();
  const data = useDashboardData(selection);

  return {
    ...selection,
    ...data,
  };
}
