export const NULL_ADDR = "0x0000000000000000000000000000000000000000";

export const mintBatch = (safeMint: Function, times: number) => {
  return Promise.all([...new Array(times).fill(0)].map(() => safeMint()));
};
