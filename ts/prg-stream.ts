import { Transfer, TransferDescriptor } from "threads-es";

export type Progress = {
	msg: string,
	iter: number,
	outof: number
};


export type Channel = TransferDescriptor<WritableStream<Progress>>;

export type Config = {
	recv: (progress: Progress) => void,
	close?: () => void,
	capacity?: number
};

export function prog_channel(config: Config): Channel {
	const { recv, close, capacity } = config;

	return Transfer(new WritableStream({
		write: recv,
		close: close,
	},
	new CountQueuingStrategy({highWaterMark: capacity ?? 1000}),
	));
}

export function preprocessing(key: string, iter: number, outof: number) : Progress {
	return {
		msg: `preprocessing/${key}`, iter, outof };
}
