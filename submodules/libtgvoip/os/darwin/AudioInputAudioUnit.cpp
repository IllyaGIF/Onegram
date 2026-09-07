//
// libtgvoip is free and unencumbered public domain software.
// For more information, see http://unlicense.org or the UNLICENSE file
// you should have received with this source code distribution.
//

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include "AudioUnitIO.h"
#include "AudioInputAudioUnit.h"
#include "../../logging.h"

using namespace tgvoip;
using namespace tgvoip::audio;

AudioInputAudioUnit::AudioInputAudioUnit(std::string deviceID, AudioUnitIO* io){
	remainingDataSize=0;
	isRecording=false;
	this->io=io;
#if TARGET_OS_OSX
	io->SetCurrentDevice(true, deviceID);
#endif
	io->AttachInput(this);
	failed=io->IsFailed();
}

AudioInputAudioUnit::~AudioInputAudioUnit(){
	io->DetachInput();
}

void AudioInputAudioUnit::Configure(uint32_t sampleRate, uint32_t bitsPerSample, uint32_t channels){
	io->Configure(sampleRate, bitsPerSample, channels);
}

void AudioInputAudioUnit::Start(){
	isRecording=true;
	io->EnableInput(true);
	failed=io->IsFailed();
}

void AudioInputAudioUnit::Stop(){
	isRecording=false;
	io->EnableInput(false);
}

void AudioInputAudioUnit::HandleBufferCallback(AudioBufferList *ioData){
	int i;
	int j;
	uint32_t configuredRate=io->GetConfiguredSampleRate();
	size_t callbackSamples=configuredRate/50; /* 20 ms */
	if(callbackSamples==0) callbackSamples=1;
	size_t callbackBytes=callbackSamples*2; /* callback PCM is s16 mono */
	for(i=0;i<ioData->mNumberBuffers;i++){
		AudioBuffer buf=ioData->mBuffers[i];
#if TARGET_OS_OSX
		assert(remainingDataSize+buf.mDataByteSize/2<10240);
		float* src=reinterpret_cast<float*>(buf.mData);
		int16_t* dst=reinterpret_cast<int16_t*>(remainingData+remainingDataSize);
		for(j=0;j<buf.mDataByteSize/4;j++){
			dst[j]=(int16_t)(src[j]*INT16_MAX);
		}
		remainingDataSize+=buf.mDataByteSize/2;
#else
		assert(remainingDataSize+buf.mDataByteSize<10240);
		memcpy(remainingData+remainingDataSize, buf.mData, buf.mDataByteSize);
		remainingDataSize+=buf.mDataByteSize;
#endif
		while(remainingDataSize>=callbackBytes){
			InvokeCallback((unsigned char*)remainingData, callbackBytes);
			remainingDataSize-=callbackBytes;
			if(remainingDataSize>0){
				memmove(remainingData, remainingData+callbackBytes, remainingDataSize);
			}
		}
	}
}

#if TARGET_OS_OSX
void AudioInputAudioUnit::SetCurrentDevice(std::string deviceID){
	io->SetCurrentDevice(true, deviceID);
}
#endif
