type ClassDictionary = Record<string, unknown>;
type ClassArray = ClassValue[];
export type ClassValue =
  | string
  | number
  | null
  | undefined
  | boolean
  | ClassDictionary
  | ClassArray;

export function cn(...inputs: ClassValue[]) {
  const classes: string[] = [];

  const append = (value: ClassValue) => {
    if (!value) return;
    if (typeof value === "string" || typeof value === "number") {
      classes.push(String(value));
      return;
    }
    if (Array.isArray(value)) {
      value.forEach(append);
      return;
    }
    if (typeof value === "object") {
      for (const [key, enabled] of Object.entries(value)) {
        if (enabled) classes.push(key);
      }
    }
  };

  inputs.forEach(append);
  return classes.join(" ");
}
