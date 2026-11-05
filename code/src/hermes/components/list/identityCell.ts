/**
 * The width an orchestration table's identity cell truncates at: about half
 * the viewport on a phone, a fixed column once the table has room. Compose it
 * with `truncate` on whichever element carries the text.
 *
 * One constant because every orchestration list needs the same answer, and a
 * table whose identity column is wider than its neighbours is what pushed
 * these tables off a phone screen in the first place.
 */
export const IDENTITY_CELL_WIDTH = "max-w-[48vw] md:max-w-[280px]";
