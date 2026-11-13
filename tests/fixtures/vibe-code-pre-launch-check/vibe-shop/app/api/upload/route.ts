import { writeFile } from "node:fs/promises";
import { NextResponse } from "next/server";

// Any caller, any file type, any size, and the caller picks the file name.
export async function POST(request: Request) {
  const form = await request.formData();
  const file = form.get("file") as File;
  await writeFile(`./public/uploads/${file.name}`, Buffer.from(await file.arrayBuffer()));
  return NextResponse.json({ url: `/uploads/${file.name}` });
}
