{
	pkgs,
	config,
	lib,
	...
}: with lib; let
	cfg = config.tg.miscs;
in {
	options.tg.miscs = {
		fixTpmInterruptBootMessage = mkOption {
			description = ''
				Wether to enable the workaround for the TPM interrupt message during boot.
				See https://bugzilla.kernel.org/show_bug.cgi?id=204121.
			'';
			default = false;
			type = types.bool;
		};
	};

	config = mkIf cfg.fixTpmInterruptBootMessage {
		boot.kernelParams = ["tpm_tis.interrupts=0"];
	};
}
