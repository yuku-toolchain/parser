import { Button } from "@/ui/button";
import { BrandIcon } from "@/ui/icon";

export default function Home() {
  return (
    <div className="flex h-full w-full flex-col items-center gap-8 p-6">
      <h1 className="mx-auto max-w-2xl text-center font-medium font-serif text-4xl/12 tracking-tighter sm:text-5xl/16">
        Yuku JavaScript Parser
      </h1>
      <p className="mx-auto max-w-xl text-center text-base/7 text-neutral-600 sm:text-[1.0625rem]/8 dark:text-neutral-400">
        A very fast JavaScript/TypeScript parser written in Zig to enable JavaScript tooling in Zig.
      </p>
      <Button size="xl" href="/playground" className="rounded-full mt-4">
        Try it out
      </Button>
      <div className="flex justify-center h-[48vh] items-center w-full absolute bottom-0 overflow-hidden right-0">
        <BrandIcon className="w-screen" />
      </div>
    </div>
  );
}
