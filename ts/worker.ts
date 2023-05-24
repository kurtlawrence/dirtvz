const ctx: Worker = self as any;

ctx.addEventListener('message', ev => {
    console.debug(ev);

    ctx.postMessage({ foo: 1 });
});